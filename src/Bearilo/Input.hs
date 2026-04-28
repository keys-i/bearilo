module Bearilo.Input (classifyKeyEvent) where

import Bearilo.Os.Types (RawKeyEvent (..), RawKeyName (..), RawKeyState (..))
import Bearilo.Types (KeyEvent (..))
import Data.Text qualified as Text

classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent
classifyKeyEvent RawKeyEvent {rawKeyName = RawKeyName keyName, rawKeyState = keyState}
  | Text.null keyName = Nothing
  | otherwise =
      case keyState of
        RawPressed -> Just (KeyPressed keyName)
        RawReleased -> Just (KeyReleased keyName)
        RawOther -> Nothing
