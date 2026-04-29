-- | Windows keyboard listener binding.
module Bearilo.Os.Windows (withWindowsKeyListener) where

import Bearilo.Os.Types (CKeyCallback, OsHookError, RawKeyEvent, withCKeyListener)
import Foreign.C.Types (CInt (..))
import Foreign.Ptr (FunPtr, Ptr)

foreign import ccall "wrapper"
  mkWindowsKeyCallback :: CKeyCallback -> IO (FunPtr CKeyCallback)

foreign import ccall safe "bearilo_windows_start"
  c_windows_start :: FunPtr CKeyCallback -> Ptr () -> IO CInt

foreign import ccall safe "bearilo_windows_stop"
  c_windows_stop :: IO CInt

-- | Listen for global key events through the Windows bridge.
withWindowsKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withWindowsKeyListener =
  withCKeyListener "windows" mkWindowsKeyCallback c_windows_start c_windows_stop
