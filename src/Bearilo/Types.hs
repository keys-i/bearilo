-- | Core config and app types.
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

-- | Preset names come from config or CLI.
type PresetName = Text

-- | Parsed Bearilo config.
data Config = Config
  { configSoundPresets :: [SoundPreset],
    configNoSurprises :: Bool
  }
  deriving stock (Eq, Show)

-- | Config after validation.
newtype ValidConfig = ValidConfig Config
  deriving stock (Eq, Show)

-- | Config ready for the runtime.
data AppConfig = AppConfig
  { appPresets :: [SoundPreset],
    appDevice :: Maybe Text,
    appNoSurprises :: Bool,
    appVolumeVariation :: Maybe VariationRange,
    appTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

-- | One named sound preset.
data SoundPreset = SoundPreset
  { presetName :: PresetName,
    presetKeyConfigs :: [KeyConfig],
    presetDisabledKeys :: [Text],
    presetVariation :: Maybe SoundVariation
  }
  deriving stock (Eq, Show)

-- | One key-matching rule inside a preset.
data KeyConfig = KeyConfig
  { keyConfigEvent :: KeyEvent,
    keyConfigKeys :: Text,
    keyConfigFiles :: [AudioFile],
    keyConfigStrategy :: Maybe PlaybackStrategy,
    keyConfigVariation :: Maybe SoundVariation
  }
  deriving stock (Eq, Show)

-- | Config event kinds and observed key events.
data KeyEvent
  = KeyPress
  | KeyRelease
  | KeyPressed Text
  | KeyReleased Text
  deriving stock (Eq, Show)

-- | Keys currently remembered as pressed.
newtype KeyMemory = KeyMemory
  { pressedKeys :: [Text]
  }
  deriving stock (Eq, Show)

-- | A configured audio file.
data AudioFile = AudioFile
  { audioFilePath :: FilePath,
    audioFileVolume :: Maybe Double
  }
  deriving stock (Eq, Show)

-- | How a key config chooses among its files.
data PlaybackStrategy
  = Random
  | Sequential
  deriving stock (Eq, Show)

-- | Optional volume and tempo variation.
data SoundVariation = SoundVariation
  { soundVariationVolume :: Maybe VariationRange,
    soundVariationTempo :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

-- | Down/up variation range.
data VariationRange = VariationRange
  { variationDown :: Double,
    variationUp :: Double
  }
  deriving stock (Eq, Show)
