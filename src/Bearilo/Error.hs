module Bearilo.Error (ConfigError (..), AppError (..), renderError) where

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

data AppError
  = AppConfigError ConfigError
  | AppError String
  deriving stock (Eq, Show)

renderError :: AppError -> String
renderError err = case err of
  AppConfigError e -> show e
  AppError message -> message
