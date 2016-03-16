{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

module Web.Users.Remote.Server (handleUserCommand, initOAuthBackend) where

import           Control.Arrow
import           Control.Monad.IO.Class
import           Control.Monad.Trans.Resource
import           Control.Monad

import           Data.Aeson
import           Data.Bifunctor              as BF
import qualified Data.ByteString.Lazy        as B
import qualified Data.ByteString             as BS
import           Data.Default.Class
import           Data.Maybe
import           Data.Monoid                 ((<>))
import           Data.Proxy
import           Data.String
import qualified Data.Text                    as T
import qualified Data.Text.Encoding           as TE
import           Data.Time.Clock

import           Database.PostgreSQL.Simple
import           Database.PostgreSQL.Simple.SqlQQ

import qualified Facebook                     as FB

import qualified Network.HTTP.Conduit         as C
import           Network.WebSockets.Sync

import           System.Random

import           Web.Users.Types              hiding (UserId)
import qualified Web.Users.Types              as U
import           Web.Users.Postgresql         ()

import           Web.Users.Remote.Types
import           Web.Users.Remote.Types.Shared

initOAuthBackend :: Connection -> IO ()
initOAuthBackend conn = do
  void $ execute conn
    [sql|
          create table if not exists login_facebook (
             lid             serial references login on delete cascade,
             fb_id           varchar(128)   not null unique,
             fb_email        varchar(128),
             fb_info         jsonb
          );
    |]
    ()

  void $ execute conn
    [sql|
          create table if not exists login_user_data (
             lid             serial references login on delete cascade,
             user_data       jsonb
          );
    |]
    ()

queryOAuthInfo :: Connection -> UserId -> IO (Maybe OAuthProviderInfo)
queryOAuthInfo conn uid = do
  r <- query conn [sql|select fb_id, fb_email from login_facebook where lid = ? limit 1;|] (Only uid)
  case r of
    [(fbId, fbEmail)] -> return $ Just (FacebookInfo fbId fbEmail)
    _ -> return Nothing

insertOAuthInfo :: Connection -> UserId -> OAuthProviderInfo -> IO Bool
insertOAuthInfo conn uid (FacebookInfo fbId fbEmail) = do
   r <- execute conn [sql|insert into login_facebook (lid, fb_id, fb_email, fb_info) values (?, ?, ?, '{}')|] (uid, fbId, fbEmail)
   return (r > 0)

queryUserData :: (FromJSON ud) => Connection -> UserId -> IO (Maybe ud)
queryUserData conn uid = do
  r <- query conn [sql|select user_data, login_user_data where lid = ? limit 1;|] (Only uid)
  case r of
    [Only ud] -> case fromJSON ud of
      Success ud -> return ud
      _ -> return Nothing
    _ -> return Nothing

insertUserData :: ToJSON ud => Connection -> UserId -> ud -> IO Bool
insertUserData conn uid udata = do
   r <- execute conn [sql|insert into login_user_data (lid, fb_id, fb_email, fb_info) values (?, ?, ?, '{}')|] (Only $ toJSON udata)
   return (r > 0)

updateUserData :: ToJSON ud => Connection -> UserId -> ud -> IO Bool
updateUserData conn uid udata = do
   r <- execute conn [sql|update login_user_data set user_data = ? where lid = ?|] (toJSON udata, uid)
   return (r > 0)

class OrdAccessRights a where
  cmpAccessRighs :: a -> a -> Ordering

checkRights :: forall udata. (Default udata, OrdAccessRights udata, FromJSON udata, ToJSON udata)
            => Proxy udata
            -> Connection
            -> SessionId
            -> UserId
            -> IO Bool
checkRights _ conn sid uid = do
  uidMine <- verifySession conn sid (fromIntegral 0)
  case uidMine of
    Just uidMine -> do
      if uidMine == uid
        then return True
        else do
          udataMine <- queryUserData conn uidMine :: IO (Maybe udata)
          udataTheirsOld <- queryUserData conn uid :: IO (Maybe udata)

          -- only update user data if we have the access rights
          case (udataMine, udataTheirsOld) of
            (Just udataMine, Just udataTheirsOld)
              | udataMine `cmpAccessRighs` udataTheirsOld == GT -> return True
            _ -> return False
    _ -> return False

handleUserCommand :: forall udata. (Default udata, OrdAccessRights udata, FromJSON udata, ToJSON udata)
                  => Connection
                  -> FB.Credentials
                  -> C.Manager
                  -> UserCommand udata UserId SessionId
                  -> IO Value
handleUserCommand conn _ _ (VerifySession sid r)   = respond r <$> verifySession conn sid 0

handleUserCommand conn _ _ (AuthUser name pwd t r) = respond r <$> do
  uid <- getUserIdByName conn name

  case uid of
    Just uid -> do
      fbinfo <- queryOAuthInfo conn uid

      case fbinfo of
        Nothing -> authUser conn name (PasswordPlain pwd) (fromIntegral t)
        _ -> return Nothing
    Nothing -> return Nothing

handleUserCommand _ cred manager (AuthFacebookUrl url perms r) = respond r <$> do
  FB.runFacebookT cred manager $
    FB.getUserAccessTokenStep1 url (map (fromString . T.unpack) $ perms ++ ["email", "public_profile"])

handleUserCommand conn cred manager (AuthFacebook url args t r) = respond r <$> do
  -- try to fetch facebook user
  fbUser <- runResourceT $ FB.runFacebookT cred manager $ do
    token <- FB.getUserAccessTokenStep2 url (map (TE.encodeUtf8 *** TE.encodeUtf8) args)
    FB.getUser "me" [] (Just token)

  let fbUserName = FB.appId cred <> FB.idCode (FB.userId fbUser)

  uid <- getUserIdByName conn fbUserName

  case uid of
    Just uid -> do
      sid <- createSession conn uid (fromIntegral t)
      return $ maybe (Left CreateSessionError) Right sid
    Nothing  -> do
      -- create random password just in case
      g <- newStdGen
      let pwd = PasswordPlain $ T.pack $ take 32 $ randomRs ('A','z') g

      uid <- createUser conn $ User fbUserName (fromMaybe fbUserName $ FB.userEmail fbUser) (makePassword pwd) True

      case uid of
        Left e -> return $ Left $ CreateUserError e
        Right uid -> do
          r1 <- insertOAuthInfo conn uid (FacebookInfo (FB.userId fbUser) (FB.userEmail fbUser))
          r2 <- insertUserData conn uid (def undefined :: udata)

          case (r1, r2) of
            (True, True) -> do
              sid <- createSession conn uid (fromIntegral t)
              return $ maybe (Left CreateSessionError) Right sid
            _ -> return $ Left CreateSessionError

handleUserCommand conn cred manager (CreateUser u_name u_email password r) = respond r <$> do
  uid <- createUser conn (User { u_active = True, u_password = makePassword (PasswordPlain password), .. })
  case uid of
    Right uid -> do
      r <- insertUserData conn uid (def undefined :: udata)
      if r
        then return $ Right uid
        else do
          deleteUser conn uid
          return $ Left UsernameAlreadyTaken
    _ -> return uid

handleUserCommand conn cred manager (UpdateUserData sid uid udata r) = respond r <$> do
  rights <- checkRights (undefined :: Proxy udata) conn sid uid

  if rights
    then updateUserData conn uid udata
    else return False

handleUserCommand conn cred manager (GetUserData sid uid r) = respond r <$> do
  rights <- checkRights (undefined :: Proxy udata) conn sid uid

  if rights
    then queryUserData conn uid
    else return Nothing

handleUserCommand conn cred manager (Logout sid r) = respond r <$> do
  destroySession conn sid
  return Ok
