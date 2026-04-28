{-# LANGUAGE ForeignFunctionInterface #-}

module Bearilo.Os.Linux (withLinuxKeyListener) where

import Bearilo.Os.Types (OsHookError, RawKeyEvent, withOsHook)
import Foreign.C.Types (CInt (..))

foreign import ccall unsafe "bearilo_linux_start_listener"
  c_linux_start_listener :: IO CInt

foreign import ccall unsafe "bearilo_linux_stop_listener"
  c_linux_stop_listener :: IO CInt

withLinuxKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withLinuxKeyListener _callback =
  withOsHook "linux" c_linux_start_listener c_linux_stop_listener
