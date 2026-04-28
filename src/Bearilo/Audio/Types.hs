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

import Bearilo.Types (SoundVariation)
import Data.ByteString (ByteString)

data AudioError
  = AudioInitError String
  | AudioMissingEmbeddedSound FilePath
  | AudioMissingFile FilePath
  | AudioUnreadableFile FilePath String
  | AudioDecodeError FilePath String
  | AudioPlayError String
  | AudioDeviceError String
  | InvalidTempoFactor Double
  deriving stock (Eq, Show)

newtype AudioEngine = AudioEngine
  {audioEnginePlaybackSlots :: PlaybackSlots}
  deriving stock (Eq, Show)

newtype OutputDeviceName = OutputDeviceName String
  deriving stock (Eq, Show)

newtype OutputDevice = OutputDevice
  {outputDeviceName :: OutputDeviceName}
  deriving stock (Eq, Show)

newtype SequentialIndex = SequentialIndex Int
  deriving stock (Eq, Show)

newtype KeyConfigId = KeyConfigId String
  deriving stock (Eq, Show)

newtype SequentialState = SequentialState [(KeyConfigId, SequentialIndex)]
  deriving stock (Eq, Show)

emptySequentialState :: SequentialState
emptySequentialState =
  SequentialState []

newtype RandomSeed = RandomSeed Int
  deriving stock (Eq, Show)

type PlaybackSlots = Int

defaultPlaybackSlots :: Int
defaultPlaybackSlots =
  8

data PlaybackState = PlaybackState
  { playbackSequentialIndex :: SequentialIndex,
    playbackSlots :: PlaybackSlots
  }
  deriving stock (Eq, Show)

data PlaybackParams = PlaybackParams
  { playbackVolume :: Double,
    playbackTempo :: Double
  }
  deriving stock (Eq, Show)

defaultPlaybackParams :: PlaybackParams
defaultPlaybackParams =
  PlaybackParams
    { playbackVolume = 1.0,
      playbackTempo = 1.0
    }

validatePlaybackParams :: PlaybackParams -> Either AudioError ()
validatePlaybackParams params
  | playbackTempo params <= 0.0 = Left (InvalidTempoFactor (playbackTempo params))
  | otherwise = Right ()

resampledLength :: Double -> Int -> Either AudioError Int
resampledLength tempo sampleCount
  | tempo <= 0.0 = Left (InvalidTempoFactor tempo)
  | tempo == 1.0 = Right sampleCount
  | sampleCount <= 0 = Right 0
  | otherwise = Right (max 1 (ceiling (fromIntegral sampleCount / tempo :: Double)))

sourceIndexForRate :: Double -> Int -> Int
sourceIndexForRate tempo outputIndex =
  floor (fromIntegral outputIndex * tempo :: Double)

resampleNearest :: Double -> [sample] -> Either AudioError [sample]
resampleNearest tempo samples
  | tempo == 1.0 && tempo > 0.0 = Right samples
  | otherwise = do
      outputLength <- resampledLength tempo (length samples)
      pure
        [ samples !! sourceIndexForRate tempo outputIndex
          | outputIndex <- [0 .. outputLength - 1]
        ]

data Sound = Sound
  { soundPath :: FilePath,
    soundBytes :: Maybe ByteString,
    soundVolume :: Double
  }
  deriving stock (Eq, Show)

data SoundSource = SoundSource
  { sourcePath :: FilePath,
    sourceBytes :: Maybe ByteString,
    sourceVolume :: Maybe Double
  }
  deriving stock (Eq, Show)

data LoadedSound = LoadedSound
  { loadedSoundPath :: FilePath,
    loadedSoundBytes :: ByteString,
    loadedSoundVolume :: Double
  }
  deriving stock (Eq, Show)

data SoundChoice = SoundChoice
  { choiceSound :: Maybe Sound,
    choicePlaybackParams :: PlaybackParams,
    choiceVariation :: SoundVariation
  }
  deriving stock (Eq, Show)

data VariationDirection
  = VariationDown
  | VariationUp
  deriving stock (Eq, Show)
