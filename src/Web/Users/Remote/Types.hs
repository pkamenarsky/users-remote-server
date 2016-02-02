{-# LANGUAGE TemplateHaskell #-}

module Web.Users.Remote.Types where

import           Data.Aeson.TH
import           Data.Int

import qualified Facebook                     as FB

import           Web.Users.Types              hiding (UserId)

type UserId = Int64

options = defaultOptions { allNullaryToStringTag = False }

class Default a where
  defaultValue :: a

data UserProviderInfo = FacebookInfo FB.User
                      | None

type UserInfo a = (a, UserProviderInfo)

data FacebookLoginError = UserEmailEmptyError
                        | CreateSessionError
                        | CreateUserError CreateUserError

