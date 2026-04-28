{-# LANGUAGE ForeignFunctionInterface #-}

module Bearilo.Os.Darwin (withDarwinKeyListener) where

import Bearilo.Os.Types (OsHookError, RawKeyEvent, withOsHook)
import Foreign.C.Types (CInt (..))

foreign import ccall unsafe "bearilo_darwin_start_listener"
  c_darwin_start_listener :: IO CInt

foreign import ccall unsafe "bearilo_darwin_stop_listener"
  c_darwin_stop_listener :: IO CInt

withDarwinKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withDarwinKeyListener _callback =
  withOsHook "darwin" c_darwin_start_listener c_darwin_stop_listener
