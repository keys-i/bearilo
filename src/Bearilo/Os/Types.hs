module Bearilo.Os.Types (RawKeyEvent (..), RawKeyState (..), OsHookError (..)) where

data RawKeyState
  = RawPressed
  | RawReleased
  | RawOther
  deriving stock (Eq, Show)

data RawKeyEvent = RawKeyEvent
  { rawKeyName :: String,
    rawKeyState :: RawKeyState
  }
  deriving stock (Eq, Show)

newtype OsHookError
  = OsHookError String
  deriving stock (Eq, Show)
