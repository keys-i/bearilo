module Bearilo.Audio.Types (Sound (..), AudioError (..)) where

newtype Sound = Sound FilePath
  deriving stock (Eq, Show)

data AudioError
  = AudioInitError String
  | AudioPlayError String
  deriving stock (Eq, Show)
