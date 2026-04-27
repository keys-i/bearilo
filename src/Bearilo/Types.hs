module Bearilo.Types (Config (..), KeyEvent (..), KeyState (..)) where

data Config = Config
  deriving stock (Eq, Show)

data KeyState
  = KeyPressed
  | KeyReleased
  deriving stock (Eq, Show)

data KeyEvent = KeyEvent
  { keyName :: String,
    keyState :: KeyState
  }
  deriving stock (Eq, Show)
