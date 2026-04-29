-- | DarwinOS keyboard listener binding.
module Bearilo.Os.Darwin (withDarwinKeyListener) where

import Bearilo.Os.Types (CKeyCallback, OsHookError, RawKeyEvent, withCKeyListener)
import Foreign.C.Types (CInt (..))
import Foreign.Ptr (FunPtr, Ptr)

foreign import ccall "wrapper"
  mkDarwinKeyCallback :: CKeyCallback -> IO (FunPtr CKeyCallback)

foreign import ccall safe "bearilo_darwin_start"
  c_darwin_start :: FunPtr CKeyCallback -> Ptr () -> IO CInt

foreign import ccall safe "bearilo_darwin_stop"
  c_darwin_stop :: IO CInt

-- | Listen for global key events through the DarwinOS bridge.
withDarwinKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
withDarwinKeyListener =
  withCKeyListener "darwin" mkDarwinKeyCallback c_darwin_start c_darwin_stop
