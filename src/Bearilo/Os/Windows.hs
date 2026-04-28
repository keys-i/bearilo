{-# LANGUAGE ForeignFunctionInterface #-}

module Bearilo.Os.Windows (withWindowsKeyListener) where

import Bearilo.Os.Types (OsHookError, RawKeyEvent, withOsHook)
import Foreign.C.Types (CInt (..))

foreign import ccall unsafe "bearilo_windows_start_listener"
  c_windows_start_listener :: IO CInt

foreign import ccall unsafe "bearilo_windows_stop_listener"
  c_windows_stop_listener :: IO CInt

withWindowsKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withWindowsKeyListener _callback =
  withOsHook "windows" c_windows_start_listener c_windows_stop_listener
