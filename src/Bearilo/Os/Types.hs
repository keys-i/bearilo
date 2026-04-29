-- | Shared types for OS keyboard listeners.
module Bearilo.Os.Types
  ( RawKeyCode (..),
    RawKeyName,
    unRawKeyName,
    RawKeyEvent (..),
    RawKeyState (..),
    OsHookError (..),
    CKeyCallback,
    mkRawKeyName,
    rawStateFromCode,
    rawEventFromC,
    withCKeyListener,
  )
where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, onException, try)
import Control.Monad (void)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Foreign.C.String (CString, peekCString)
import Foreign.C.Types (CInt)
import Foreign.Ptr (FunPtr, Ptr, freeHaskellFunPtr, nullPtr)

-- | Raw key code reported by the OS bridge.
newtype RawKeyCode = RawKeyCode
  { unRawKeyCode :: Int
  }
  deriving stock (Eq, Show)

-- | Non-empty raw key name reported by the OS bridge.
newtype RawKeyName = RawKeyName
  { unRawKeyName :: Text
  }
  deriving stock (Eq, Show)

-- | Raw press/release state from the OS bridge.
data RawKeyState
  = RawPressed
  | RawReleased
  | RawOther
  deriving stock (Eq, Show)

-- | Raw key event before app-level classification.
data RawKeyEvent = RawKeyEvent
  { rawKeyCode :: RawKeyCode,
    rawKeyName :: RawKeyName,
    rawKeyState :: RawKeyState
  }
  deriving stock (Eq, Show)

-- | Things that can go wrong at the OS listener boundary.
data OsHookError
  = OsListenerStartFailed String Int
  | OsListenerStopFailed String Int
  | OsCallbackFailed String
  | OsInvalidRawEvent Int Int
  | OsUnsupportedPlatform String
  deriving stock (Eq, Show)

-- | Callback shape used by the C bridges.
type CKeyCallback = CInt -> CInt -> CString -> Ptr () -> IO ()

-- | Build a raw key name when the OS gave us something useful.
mkRawKeyName :: String -> Maybe RawKeyName
mkRawKeyName name
  | Text.null text = Nothing
  | otherwise = Just (RawKeyName text)
  where
    text = Text.pack name

-- | Decode the C bridge's state code.
rawStateFromCode :: Int -> RawKeyState
rawStateFromCode 1 = RawPressed
rawStateFromCode 0 = RawReleased
rawStateFromCode _ = RawOther

-- | Convert C callback data into a raw key event.
rawEventFromC :: Int -> Int -> Maybe String -> Maybe RawKeyEvent
rawEventFromC keyCode stateCode maybeName = do
  keyName <- mkRawKeyName (fromMaybe "" maybeName) <|> fallbackKeyName
  pure
    RawKeyEvent
      { rawKeyCode = RawKeyCode keyCode,
        rawKeyName = keyName,
        rawKeyState = rawStateFromCode stateCode
      }
  where
    fallbackKeyName
      | keyCode >= 0 = mkRawKeyName ("KeyCode-" <> show keyCode)
      | otherwise = Nothing

-- | Run a C listener while translating callbacks into Haskell events.
withCKeyListener ::
  String ->
  (CKeyCallback -> IO (FunPtr CKeyCallback)) ->
  (FunPtr CKeyCallback -> Ptr () -> IO CInt) ->
  IO CInt ->
  (RawKeyEvent -> IO ()) ->
  IO a ->
  IO (Either OsHookError a)
withCKeyListener platform makeCallback start stop callback action = do
  callbackErrorRef <- newIORef Nothing
  callbackPtr <- makeCallback (dispatch callbackErrorRef)
  result <- runListener callbackErrorRef callbackPtr `onException` cleanup callbackPtr
  freeHaskellFunPtr callbackPtr
  pure result
  where
    runListener callbackErrorRef callbackPtr = do
      startCode <- start callbackPtr nullPtr
      if startCode /= 0
        then pure (Left (OsListenerStartFailed platform (fromIntegral startCode)))
        else do
          actionResult <- action `onException` void stop
          stopCode <- stop
          callbackError <- readIORef callbackErrorRef
          if stopCode /= 0
            then pure (Left (OsListenerStopFailed platform (fromIntegral stopCode)))
            else case callbackError of
              Just err -> pure (Left err)
              Nothing -> pure (Right actionResult)

    cleanup callbackPtr = do
      void stop
      freeHaskellFunPtr callbackPtr

    dispatch callbackErrorRef keyCode stateCode keyNamePtr _userData = do
      maybeName <-
        if keyNamePtr == nullPtr
          then pure Nothing
          else Just <$> peekCString keyNamePtr

      case rawEventFromC (fromIntegral keyCode) (fromIntegral stateCode) maybeName of
        Nothing ->
          writeIORef
            callbackErrorRef
            (Just (OsInvalidRawEvent (fromIntegral keyCode) (fromIntegral stateCode)))
        Just event -> do
          callbackResult <- tryAny (callback event)
          case callbackResult of
            Left err ->
              writeIORef callbackErrorRef (Just (OsCallbackFailed (show err)))
            Right () ->
              pure ()

    tryAny :: IO a -> IO (Either SomeException a)
    tryAny =
      try
