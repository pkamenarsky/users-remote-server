module Web.Users.Remote.Types.Shared where

import Network.WebSockets.Sync.Request

import Data.JSON
import Data.Either
import Data.Maybe
import Data.List (List ())
import Data.Tuple
import Data.Set (Set ())
import Control.Monad.Aff
import Prelude

type Text = String

data CreateUserError  = UsernameOrEmailAlreadyTaken 
|
InvalidPassword 
|
UsernameAlreadyTaken 
|
EmailAlreadyTaken 
|
UsernameAndEmailAlreadyTaken 


instance createUserErrorToJson ::  ToJSON (CreateUserError ) where
  toJSON (UsernameOrEmailAlreadyTaken ) = object $
    [ "tag" .= "UsernameOrEmailAlreadyTaken"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (InvalidPassword ) = object $
    [ "tag" .= "InvalidPassword"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (UsernameAlreadyTaken ) = object $
    [ "tag" .= "UsernameAlreadyTaken"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (EmailAlreadyTaken ) = object $
    [ "tag" .= "EmailAlreadyTaken"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (UsernameAndEmailAlreadyTaken ) = object $
    [ "tag" .= "UsernameAndEmailAlreadyTaken"
    , "contents" .= ([] :: Array String)
    ]


instance createUserErrorFromJson ::  FromJSON (CreateUserError ) where
  parseJSON (JObject o) = do
    tag <- o .: "tag"
    case tag of
      "UsernameOrEmailAlreadyTaken" -> do
         return UsernameOrEmailAlreadyTaken

      "InvalidPassword" -> do
         return InvalidPassword

      "UsernameAlreadyTaken" -> do
         return UsernameAlreadyTaken

      "EmailAlreadyTaken" -> do
         return EmailAlreadyTaken

      "UsernameAndEmailAlreadyTaken" -> do
         return UsernameAndEmailAlreadyTaken



data FacebookLoginError  = UserEmailEmptyError 
|
CreateSessionError 
|
CreateUserError CreateUserError


instance facebookLoginErrorToJson ::  ToJSON (FacebookLoginError ) where
  toJSON (UserEmailEmptyError ) = object $
    [ "tag" .= "UserEmailEmptyError"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (CreateSessionError ) = object $
    [ "tag" .= "CreateSessionError"
    , "contents" .= ([] :: Array String)
    ]
  toJSON (CreateUserError x0) = object $
    [ "tag" .= "CreateUserError"
    , "contents" .= toJSON x0
    ]


instance facebookLoginErrorFromJson ::  FromJSON (FacebookLoginError ) where
  parseJSON (JObject o) = do
    tag <- o .: "tag"
    case tag of
      "UserEmailEmptyError" -> do
         return UserEmailEmptyError

      "CreateSessionError" -> do
         return CreateSessionError

      "CreateUserError" -> do
         x0 <- o .: "contents"
         CreateUserError <$> parseJSON x0



data UserCommand uinfo uid sid = VerifySession SessionId (Proxy (Maybe uid))
|
CreateUser (User uinfo) Text (Proxy ((Either CreateUserError) uid))
|
AuthUser Text Text Int (Proxy (Maybe sid))
|
AuthFacebookUrl Text (Array  Text) (Proxy Text)
|
AuthFacebook Text (Array  ((Tuple  Text) Text)) Int (Proxy ((Either FacebookLoginError) sid))
|
GetUserById uid (Proxy (Maybe (User uinfo)))
|
Logout SessionId (Proxy Unit )


instance userCommandToJson :: (ToJSON uinfo, ToJSON uid, ToJSON sid) =>  ToJSON (UserCommand uinfo uid sid) where
  toJSON (VerifySession x0 x1) = object $
    [ "tag" .= "VerifySession"
    , "contents" .= [toJSON x0, toJSON x1]
    ]
  toJSON (CreateUser x0 x1 x2) = object $
    [ "tag" .= "CreateUser"
    , "contents" .= [toJSON x0, toJSON x1, toJSON x2]
    ]
  toJSON (AuthUser x0 x1 x2 x3) = object $
    [ "tag" .= "AuthUser"
    , "contents" .= [toJSON x0, toJSON x1, toJSON x2, toJSON x3]
    ]
  toJSON (AuthFacebookUrl x0 x1 x2) = object $
    [ "tag" .= "AuthFacebookUrl"
    , "contents" .= [toJSON x0, toJSON x1, toJSON x2]
    ]
  toJSON (AuthFacebook x0 x1 x2 x3) = object $
    [ "tag" .= "AuthFacebook"
    , "contents" .= [toJSON x0, toJSON x1, toJSON x2, toJSON x3]
    ]
  toJSON (GetUserById x0 x1) = object $
    [ "tag" .= "GetUserById"
    , "contents" .= [toJSON x0, toJSON x1]
    ]
  toJSON (Logout x0 x1) = object $
    [ "tag" .= "Logout"
    , "contents" .= [toJSON x0, toJSON x1]
    ]


instance userCommandFromJson :: (FromJSON uinfo, FromJSON uid, FromJSON sid) =>  FromJSON (UserCommand uinfo uid sid) where
  parseJSON (JObject o) = do
    tag <- o .: "tag"
    case tag of
      "VerifySession" -> do
         [x0, x1] <- o .: "contents"
         VerifySession <$> parseJSON x0 <*> parseJSON x1

      "CreateUser" -> do
         [x0, x1, x2] <- o .: "contents"
         CreateUser <$> parseJSON x0 <*> parseJSON x1 <*> parseJSON x2

      "AuthUser" -> do
         [x0, x1, x2, x3] <- o .: "contents"
         AuthUser <$> parseJSON x0 <*> parseJSON x1 <*> parseJSON x2 <*> parseJSON x3

      "AuthFacebookUrl" -> do
         [x0, x1, x2] <- o .: "contents"
         AuthFacebookUrl <$> parseJSON x0 <*> parseJSON x1 <*> parseJSON x2

      "AuthFacebook" -> do
         [x0, x1, x2, x3] <- o .: "contents"
         AuthFacebook <$> parseJSON x0 <*> parseJSON x1 <*> parseJSON x2 <*> parseJSON x3

      "GetUserById" -> do
         [x0, x1] <- o .: "contents"
         GetUserById <$> parseJSON x0 <*> parseJSON x1

      "Logout" -> do
         [x0, x1] <- o .: "contents"
         Logout <$> parseJSON x0 <*> parseJSON x1



data User a = User {
  u_name :: Text,
  u_email :: Text,
  u_password :: Password,
  u_active :: Boolean,
  u_more :: a
}

instance userToJson :: (ToJSON a) =>  ToJSON (User a) where
  toJSON (User v) = object $
    [ "tag" .= "User"
    , "u_name" .= v.u_name
    , "u_email" .= v.u_email
    , "u_password" .= v.u_password
    , "u_active" .= v.u_active
    , "u_more" .= v.u_more
    ]


instance userFromJson :: (FromJSON a) =>  FromJSON (User a) where
  parseJSON (JObject o) = do
        u_name <- o .: "u_name"
        u_email <- o .: "u_email"
        u_password <- o .: "u_password"
        u_active <- o .: "u_active"
        u_more <- o .: "u_more"
        return $ User { u_name : u_name, u_email : u_email, u_password : u_password, u_active : u_active, u_more : u_more }


data Password  = PasswordHash Text
|
PasswordHidden 


instance passwordToJson ::  ToJSON (Password ) where
  toJSON (PasswordHash x0) = object $
    [ "tag" .= "PasswordHash"
    , "contents" .= toJSON x0
    ]
  toJSON (PasswordHidden ) = object $
    [ "tag" .= "PasswordHidden"
    , "contents" .= ([] :: Array String)
    ]


instance passwordFromJson ::  FromJSON (Password ) where
  parseJSON (JObject o) = do
    tag <- o .: "tag"
    case tag of
      "PasswordHash" -> do
         x0 <- o .: "contents"
         PasswordHash <$> parseJSON x0

      "PasswordHidden" -> do
         return PasswordHidden



newtype SessionId  = SessionId {
  unSessionId :: Text
}

instance sessionIdToJson ::  ToJSON (SessionId ) where
  toJSON (SessionId v) = object $
    [ "tag" .= "SessionId"
    , "unSessionId" .= v.unSessionId
    ]


instance sessionIdFromJson ::  FromJSON (SessionId ) where
  parseJSON (JObject o) = do
        unSessionId <- o .: "unSessionId"
        return $ SessionId { unSessionId : unSessionId }
