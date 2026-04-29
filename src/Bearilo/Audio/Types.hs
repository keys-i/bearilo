-- | Audio-only types and small pure helpers.
module Bearilo.Audio.Types
  ( AudioEngine (..),
    AudioError (..),
    KeyConfigId (..),
    LoadedSound (..),
    OutputDevice (..),
    OutputDeviceName (..),
    PlaybackParams (..),
    PlaybackSlots,
    PlaybackState (..),
    RandomSeed (..),
    SequentialIndex (..),
    SequentialState (..),
    Sound (..),
    SoundChoice (..),
    SoundSource (..),
    VariationDirection (..),
    defaultPlaybackSlots,
    defaultPlaybackParams,
    emptySequentialState,
    resampleNearest,
    resampledLength,
    sourceIndexForRate,
    validatePlaybackParams,
  )
where

import Bearilo.Types (KeyConfig, SoundVariation)
import Data.ByteString (ByteString)

-- | Errors from loading or playing audio.
data AudioError
  = AudioInitError String
  | AudioInterrupted
  | AudioMissingEmbeddedSound FilePath
  | AudioMissingFile FilePath
  | AudioUnreadableFile FilePath String
  | AudioDecodeError FilePath String
  | AudioPlayError String
  | AudioDeviceError String
  | InvalidTempoFactor Double
  deriving stock (Eq, Show)

-- | Handle for the active audio backend.
newtype AudioEngine = AudioEngine
  {audioEnginePlaybackSlots :: PlaybackSlots}
  deriving stock (Eq, Show)

-- | Output device name.
newtype OutputDeviceName = OutputDeviceName String
  deriving stock (Eq, Show)

-- | Audio output device.
newtype OutputDevice = OutputDevice
  {outputDeviceName :: OutputDeviceName}
  deriving stock (Eq, Show)

-- | Position in sequential playback.
newtype SequentialIndex = SequentialIndex Int
  deriving stock (Eq, Show)

-- | Stable id for one key config.
newtype KeyConfigId = KeyConfigId String
  deriving stock (Eq, Show)

-- | Sequential indices by key config.
newtype SequentialState = SequentialState [(KeyConfigId, SequentialIndex)]
  deriving stock (Eq, Show)

-- | Empty sequential playback state.
emptySequentialState :: SequentialState
emptySequentialState =
  SequentialState []

-- | Seed for deterministic random choice.
newtype RandomSeed = RandomSeed Int
  deriving stock (Eq, Show)

-- | How many sounds can play at once.
type PlaybackSlots = Int

-- | Default number of concurrent playback slots.
defaultPlaybackSlots :: Int
defaultPlaybackSlots =
  8

-- | Playback state kept by the audio layer.
data PlaybackState = PlaybackState
  { playbackSequentialIndex :: SequentialIndex,
    playbackSlots :: PlaybackSlots
  }
  deriving stock (Eq, Show)

-- | Volume and tempo for one play call.
data PlaybackParams = PlaybackParams
  { playbackVolume :: Double,
    playbackTempo :: Double
  }
  deriving stock (Eq, Show)

-- | Normal playback parameters.
defaultPlaybackParams :: PlaybackParams
defaultPlaybackParams =
  PlaybackParams
    { playbackVolume = 1.0,
      playbackTempo = 1.0
    }

-- | Check playback parameters before touching SDL.
validatePlaybackParams :: PlaybackParams -> Either AudioError ()
validatePlaybackParams params
  | playbackTempo params <= 0.0 = Left (InvalidTempoFactor (playbackTempo params))
  | otherwise = Right ()

-- | Work out the sample count after nearest-neighbor resampling.
resampledLength :: Double -> Int -> Either AudioError Int
resampledLength tempo sampleCount
  | tempo <= 0.0 = Left (InvalidTempoFactor tempo)
  | tempo == 1.0 = Right sampleCount
  | sampleCount <= 0 = Right 0
  | otherwise = Right (max 1 (ceiling (fromIntegral sampleCount / tempo :: Double)))

-- | Map an output sample index back to the source sample index.
sourceIndexForRate :: Double -> Int -> Int
sourceIndexForRate tempo outputIndex =
  floor (fromIntegral outputIndex * tempo :: Double)

-- | Simple nearest-neighbor resampling.
resampleNearest :: Double -> [sample] -> Either AudioError [sample]
resampleNearest tempo samples
  | tempo == 1.0 && tempo > 0.0 = Right samples
  | otherwise = do
      outputLength <- resampledLength tempo (length samples)
      pure
        [ samples !! sourceIndexForRate tempo outputIndex
          | outputIndex <- [0 .. outputLength - 1]
        ]

-- | A sound selected for playback.
data Sound = Sound
  { soundPath :: FilePath,
    soundBytes :: Maybe ByteString,
    soundVolume :: Double
  }
  deriving stock (Eq, Show)

-- | A sound source before it is loaded.
data SoundSource = SoundSource
  { sourcePath :: FilePath,
    sourceBytes :: Maybe ByteString,
    sourceVolume :: Maybe Double
  }
  deriving stock (Eq, Show)

-- | Loaded sound bytes ready for SDL_mixer.
data LoadedSound = LoadedSound
  { loadedSoundPath :: FilePath,
    loadedSoundBytes :: ByteString,
    loadedSoundVolume :: Double
  }
  deriving stock (Eq, Show)

-- | The sound and playback settings picked for an event.
data SoundChoice = SoundChoice
  { choiceSound :: Maybe Sound,
    choiceKeyConfig :: Maybe KeyConfig,
    choicePlaybackParams :: PlaybackParams,
    choiceVariation :: SoundVariation
  }
  deriving stock (Eq, Show)

-- | Direction used when applying variation.
data VariationDirection
  = VariationDown
  | VariationUp
  deriving stock (Eq, Show)
