{-# LANGUAGE CPP #-}

-- | Pick the keyboard listener for the current OS.
module Bearilo.Os (withKeyListener) where

import Bearilo.Os.Types (OsHookError (..), RawKeyEvent)

#if defined(linux_HOST_OS)
import Bearilo.Os.Linux (withLinuxKeyListener)
#elif defined(darwin_HOST_OS)
import Bearilo.Os.Darwin (withDarwinKeyListener)
#elif defined(mingw32_HOST_OS)
import Bearilo.Os.Windows (withWindowsKeyListener)
#endif

-- | Run an action while the global key listener is active.
withKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)
#if defined(linux_HOST_OS)
withKeyListener = withLinuxKeyListener
#elif defined(darwin_HOST_OS)
withKeyListener = withDarwinKeyListener
#elif defined(mingw32_HOST_OS)
withKeyListener = withWindowsKeyListener
#else
withKeyListener _ _ =
  pure (Left (OsUnsupportedPlatform "global keyboard listener is not supported on this platform"))
#endif
