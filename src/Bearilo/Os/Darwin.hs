module Bearilo.Os.Darwin (withDarwinKeyListener) where

import Bearilo.Os.Types (OsHookError (..), RawKeyEvent)

withDarwinKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withDarwinKeyListener _ action = Right <$> action
