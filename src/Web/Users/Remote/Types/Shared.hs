{-# LANGUAGE TemplateHaskell #-}

module Web.Users.Remote.Types.Shared where

import           Data.Aeson.TH
import           Data.Proxy

import           Data.List                    (intercalate)
import qualified Data.Text                    as T
import           Data.Time.Clock

import qualified Facebook                     as FB

import           Purescript.Interop

import           Web.Users.Types              hiding (UserId)
import           Web.Users.Remote.Types

data UserCommand uinfo uid sid
  = VerifySession SessionId (Proxy (Maybe uid))
  | CreateUser (User uinfo) T.Text (Proxy (Either CreateUserError uid))
  | AuthUser T.Text T.Text Int (Proxy (Maybe sid))
  | AuthFacebookUrl T.Text [T.Text] (Proxy T.Text)
  | AuthFacebook T.Text [(T.Text, T.Text)] Int (Proxy (Either FacebookLoginError sid))
  | GetUserById uid (Proxy (Maybe (User uinfo)))
  | Logout SessionId (Proxy ())

deriveJSON options ''Proxy
deriveJSON options ''UserCommand

deriveJSON options ''CreateUserError
deriveJSON options ''NominalDiffTime
deriveJSON options ''PasswordPlain
deriveJSON options ''Password

deriveToJSON options ''FB.GeoCoordinates
deriveToJSON options ''FB.Location
deriveToJSON options ''FB.Place
deriveToJSON options ''FB.User

deriveJSON options ''UserProviderInfo

deriveJSON options ''FacebookLoginError

mkExports (Just ((intercalate "\n"
  [ "module Web.Users.Remote.Types.Shared where"
  , ""
  , "import Network.WebSockets.Sync.Request"
  , ""
  ])
  , (intercalate "\n"
  [ ""
  , ""
  , "instance userToJSON :: (ToJSON a) => ToJSON (User a) where"
  , "  toJSON (User user) ="
  , "    object"
  , "      [ \"name\" .= user.u_name"
  , "      , \"email\" .= user.u_email"
  , "      , \"active\" .= user.u_active"
  , "      , \"more\" .= user.u_more"
  , "      ]"
  , ""
  , "instance userFromJSON :: (FromJSON a) => FromJSON (User a) where"
  , "  parseJSON (JObject obj) = do"
  , "    u_name <- obj .: \"name\""
  , "    u_email <- obj .: \"email\""
  , "    u_password <- pure PasswordHidden"
  , "    u_active <- obj .: \"active\""
  , "    u_more <- obj .: \"more\""
  , "    return $ User { u_name, u_email, u_password, u_active, u_more }"
  , ""
  , "instance sessionIdToJson ::  ToJSON (SessionId ) where"
  , "  toJSON (SessionId v) = toJSON v.unSessionId"
  , ""
  , "instance sessionIdFromJson ::  FromJSON (SessionId ) where"
  , "  parseJSON (JString v) = return $ SessionId { unSessionId : v }"
  , "  parseJSON _ = fail \"Could not parse SessionId\""
  , ""
  ])
  , "ps/Web/Users/Remote/Types/Shared.purs"))

  [ (''CreateUserError, True)
  , (''FacebookLoginError, True)
  , (''UserCommand, True)
  , (''Password, True)
  , (''SessionId, False)
  , (''User, False)
  ]
