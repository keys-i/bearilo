module Bearilo.Os.Windows (withWindowsKeyListener) where

import Bearilo.Os.Types (OsHookError (..), RawKeyEvent)

withWindowsKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withWindowsKeyListener _ action = Right <$> action
