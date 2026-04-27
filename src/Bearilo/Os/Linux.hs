module Bearilo.Os.Linux (withLinuxKeyListener) where

import Bearilo.Os.Types (OsHookError, RawKeyEvent)

withLinuxKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withLinuxKeyListener _ action = Right <$> action
