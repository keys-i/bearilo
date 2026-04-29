-- | Linux keyboard listener binding.
module Bearilo.Os.Linux (withLinuxKeyListener) where

import Bearilo.Os.Types (CKeyCallback, OsHookError, RawKeyEvent, withCKeyListener)
import Foreign.C.Types (CInt (..))
import Foreign.Ptr (FunPtr, Ptr)

foreign import ccall "wrapper"
  mkLinuxKeyCallback :: CKeyCallback -> IO (FunPtr CKeyCallback)

foreign import ccall safe "bearilo_linux_start"
  c_linux_start :: FunPtr CKeyCallback -> Ptr () -> IO CInt

foreign import ccall safe "bearilo_linux_stop"
  c_linux_stop :: IO CInt

-- | Listen for global key events through the Linux bridge.
withLinuxKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withLinuxKeyListener =
  withCKeyListener "linux" mkLinuxKeyCallback c_linux_start c_linux_stop
