module Bearilo.Input
  ( classifyKeyEvent,
    emptyKeyMemory,
    shouldPlayEvent,
    updateKeyMemory,
  )
where

import Bearilo.Os.Types (RawKeyEvent (..), RawKeyState (..), unRawKeyName)
import Bearilo.Types (KeyEvent (..), KeyMemory (..))
import Data.List (delete)

classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent
classifyKeyEvent RawKeyEvent {rawKeyName = keyName, rawKeyState = keyState} =
  case keyState of
    RawPressed -> Just (KeyPressed (unRawKeyName keyName))
    RawReleased -> Just (KeyReleased (unRawKeyName keyName))
    RawOther -> Nothing

emptyKeyMemory :: KeyMemory
emptyKeyMemory =
  KeyMemory {pressedKeys = []}

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
