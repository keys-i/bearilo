module Bearilo.Os (withKeyListener) where

import Bearilo.Os.Types (OsHookError, RawKeyEvent)

withKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withKeyListener _ action = Right <$> action
