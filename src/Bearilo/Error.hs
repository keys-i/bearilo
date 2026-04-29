-- | Error values shared by the runtime.
module Bearilo.Error (ConfigError (..), AppError (..), renderError) where

import Bearilo.Audio.Types (AudioError)
import Bearilo.Os.Types (OsHookError)

-- | Things that can go wrong while reading config.
data ConfigError
  = ConfigParseError String
  | ConfigPathMissing FilePath
  | PresetNotFound String
  | NoAudioFiles String
  | MissingConfigField String
  | InvalidConfigField String
  | InvalidKeyEvent String
  | InvalidPlaybackStrategy String
  deriving stock (Eq, Show)

-- | Top-level app errors.
data AppError
  = AppConfigError ConfigError
  | AppAudioError AudioError
  | AppOsHookError OsHookError
  | AppError String
  deriving stock (Eq, Show)

-- | Turn an app error into text for stderr or logs.
renderError :: AppError -> String
renderError err =
  case err of
    AppConfigError e -> show e
    AppAudioError e -> show e
    AppOsHookError e -> show e
    AppError message -> message
