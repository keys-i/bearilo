module Bearilo.Input (classifyKeyEvent) where

import Bearilo.Os.Types (RawKeyEvent (..), RawKeyState (..), unRawKeyName)
import Bearilo.Types (KeyEvent (..))

classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent
classifyKeyEvent RawKeyEvent {rawKeyName = keyName, rawKeyState = keyState} =
  case keyState of
    RawPressed -> Just (KeyPressed (unRawKeyName keyName))
    RawReleased -> Just (KeyReleased (unRawKeyName keyName))
    RawOther -> Nothing
