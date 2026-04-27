module Bearilo.Input (classifyKeyEvent) where

import Bearilo.Os.Types (RawKeyEvent)
import Bearilo.Types (KeyEvent)

classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent
classifyKeyEvent _ = Nothing
