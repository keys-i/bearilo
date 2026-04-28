module Bearilo.Os.Types
  ( RawKeyName (..),
    RawKeyEvent (..),
    RawKeyState (..),
    OsHookError (..),
    withOsHook,
  )
where

import Control.Exception (onException)
import Control.Monad (void)
import Data.Text (Text)
import Foreign.C.Types (CInt)

newtype RawKeyName = RawKeyName
  { unRawKeyName :: Text
  }
  deriving stock (Eq, Show)

data RawKeyState
  = RawPressed
  | RawReleased
  | RawOther
  deriving stock (Eq, Show)

data RawKeyEvent = RawKeyEvent
  { rawKeyName :: RawKeyName,
    rawKeyState :: RawKeyState
  }
  deriving stock (Eq, Show)

data OsHookError
  = OsListenerStartFailed String Int
  | OsListenerStopFailed String Int
  | OsUnsupportedPlatform String
  | OsCallbackFailed String
  deriving stock (Eq, Show)

withOsHook :: String -> IO CInt -> IO CInt -> IO a -> IO (Either OsHookError a)
withOsHook platform start stop action = do
  startCode <- start
  if startCode /= 0
    then pure (Left (OsListenerStartFailed platform (fromIntegral startCode)))
    else do
      result <- action `onException` void stop
      stopCode <- stop
      if stopCode /= 0
        then pure (Left (OsListenerStopFailed platform (fromIntegral stopCode)))
        else pure (Right result)
