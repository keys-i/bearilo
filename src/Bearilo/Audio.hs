module Bearilo.Audio (withAudio, playSound) where

import Bearilo.Audio.Types (Sound)

withAudio :: (IO () -> IO a) -> IO a
withAudio action = action (pure ())

playSound :: Sound -> IO ()
playSound _ = pure ()
