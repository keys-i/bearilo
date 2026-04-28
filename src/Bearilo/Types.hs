module Bearilo.Types
  ( Config (..),
    SoundPreset (..),
    KeyConfig (..),
    KeyEvent (..),
    KeyMemory (..),
    AudioFile (..),
    PlaybackStrategy (..),
    PresetName,
    VariationRange (..),
    SoundVariation (..),
    ValidConfig (..),
    AppConfig (..),
  )
where

import Data.Text (Text)

type PresetName = Text

data Config = Config
  { configSoundPresets :: [SoundPreset],
    configNoSurprises :: Bool
  }
  deriving stock (Eq, Show)

newtype ValidConfig = ValidConfig Config
  deriving stock (Eq, Show)

data AppConfig = AppConfig
  { appPresets :: [SoundPreset],
    appDevice :: Maybe Text,
    appNoSurprises :: Bool,
    appVolumeVariation :: Maybe VariationRange,
    appTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

data SoundPreset = SoundPreset
  { presetName :: PresetName,
    presetKeyConfigs :: [KeyConfig],
    presetDisabledKeys :: [Text],
    presetVariation :: Maybe SoundVariation
  }
  deriving stock (Eq, Show)

data KeyConfig = KeyConfig
  { keyConfigEvent :: KeyEvent,
    keyConfigKeys :: Text,
    keyConfigFiles :: [AudioFile],
    keyConfigStrategy :: Maybe PlaybackStrategy,
    keyConfigVariation :: Maybe SoundVariation
  }
  deriving stock (Eq, Show)

data KeyEvent
  = KeyPress
  | KeyRelease
  | KeyPressed Text
  | KeyReleased Text
  deriving stock (Eq, Show)

newtype KeyMemory = KeyMemory
  { pressedKeys :: [Text]
  }
  deriving stock (Eq, Show)

data AudioFile = AudioFile
  { audioFilePath :: FilePath,
    audioFileVolume :: Maybe Double
  }
  deriving stock (Eq, Show)

data PlaybackStrategy
  = Random
  | Sequential
  deriving stock (Eq, Show)

data SoundVariation = SoundVariation
  { soundVariationVolume :: Maybe VariationRange,
    soundVariationTempo :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

data VariationRange = VariationRange
  { variationDown :: Double,
    variationUp :: Double
  }
  deriving stock (Eq, Show)
