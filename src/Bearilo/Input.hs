-- | Pure key event classification and press memory.
module Bearilo.Input
  ( classifyKeyEvent,
    emptyKeyMemory,
    normaliseRawKeyName,
    normalizeKeyName,
    shouldPlayEvent,
    updateKeyMemory,
  )
where

import Bearilo.Os.Types (RawKeyCode (..), RawKeyEvent (..), RawKeyState (..), mkRawKeyName, unRawKeyName)
import Bearilo.Types (KeyEvent (..), KeyMemory (..))
import Data.List (delete)
import Data.Text (Text)
import Data.Text qualified as Text

-- | Convert a raw OS event into the app's key event type.
classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent
classifyKeyEvent rawEvent =
  case keyState of
    RawPressed -> Just (KeyPressed keyName)
    RawReleased -> Just (KeyReleased keyName)
    RawOther -> Nothing
  where
    normalized =
      normaliseRawKeyName rawEvent

    keyName =
      unRawKeyName (rawKeyName normalized)

    keyState =
      rawKeyState normalized

-- | Normalize raw key names before config matching.
normaliseRawKeyName :: RawKeyEvent -> RawKeyEvent
normaliseRawKeyName event
  | rawCode `elem` [36, 76] = event {rawKeyName = returnKeyName}
  | otherwise = event {rawKeyName = normalizedName}
  where
    RawKeyCode rawCode =
      rawKeyCode event

    normalizedName =
      case mkRawKeyName (Text.unpack (normalizeKeyName (unRawKeyName (rawKeyName event)))) of
        Just keyName -> keyName
        Nothing -> rawKeyName event

    returnKeyName =
      case mkRawKeyName "Return" of
        Just keyName -> keyName
        Nothing -> rawKeyName event

-- | Match the names Daktilo config expects.
normalizeKeyName :: Text -> Text
normalizeKeyName "Enter" = "Return"
normalizeKeyName "\r" = "Return"
normalizeKeyName "\n" = "Return"
normalizeKeyName "KeyCode-36" = "Return"
normalizeKeyName "KeyCode-76" = "Return"
normalizeKeyName keyName = keyName

-- | Start with no keys held down.
emptyKeyMemory :: KeyMemory
emptyKeyMemory =
  KeyMemory {pressedKeys = []}

-- | Decide whether this key event should play a sound.
shouldPlayEvent :: KeyMemory -> KeyEvent -> (Bool, KeyMemory)
shouldPlayEvent memory event =
  (shouldPlay, updateKeyMemory memory event)
  where
    shouldPlay =
      case event of
        KeyPressed keyName -> keyName `notElem` pressedKeys memory
        KeyReleased _ -> True
        KeyPress -> True
        KeyRelease -> True

-- | Update the remembered pressed keys.
updateKeyMemory :: KeyMemory -> KeyEvent -> KeyMemory
updateKeyMemory memory event =
  case event of
    KeyPressed keyName ->
      if keyName `elem` pressedKeys memory
        then memory
        else memory {pressedKeys = keyName : pressedKeys memory}
    KeyReleased keyName ->
      memory {pressedKeys = delete keyName (pressedKeys memory)}
    KeyPress -> memory
    KeyRelease -> memory
