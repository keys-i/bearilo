-- | Parse config files and merge them with CLI options.
module Bearilo.Config
  ( applyNoSurprises,
    mergeConfig,
    parseConfig,
    resolveConfigPath,
    parseKeyEvent,
    parsePlaybackStrategy,
    resolveHiddenPreset,
    selectDefaultPreset,
    selectPresets,
    validateConfig,
  )
where

import Bearilo.Cli (CliOptions (..))
import Bearilo.Error (ConfigError (..))
import Bearilo.Types
import Control.Applicative ((<|>))
import Control.Monad (void)
import Data.Foldable (traverse_)
import Data.List (find)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory
  ( XdgDirectory (XdgConfig),
    doesFileExist,
    getXdgDirectory,
  )
import System.FilePath ((</>))
import Text.Parsec
  ( alphaNum,
    char,
    choice,
    digit,
    eof,
    many,
    many1,
    noneOf,
    oneOf,
    optionMaybe,
    parse,
    sepEndBy,
    skipMany,
    string,
    try,
  )
import Text.Parsec.Text (Parser)

data TomlValue
  = TomlString Text
  | TomlNumber Double
  | TomlBool Bool
  | TomlArray [TomlValue]
  | TomlInlineTable [(Text, TomlValue)]
  deriving stock (Eq, Show)

data TomlItem
  = TomlPresetHeader
  | TomlAssignment Text TomlValue
  deriving stock (Eq, Show)

data TomlDocument = TomlDocument
  { tomlTopLevel :: [(Text, TomlValue)],
    tomlPresets :: [[(Text, TomlValue)]]
  }
  deriving stock (Eq, Show)

-- | Parse Bearilo's small TOML config format.
parseConfig :: Text -> Either ConfigError Config
parseConfig input =
  case parse tomlDocument "bearilo config" input of
    Left err -> Left (ConfigParseError (show err))
    Right document -> decodeDocument document

-- | Check config rules that are easier to catch before playback.
validateConfig :: Config -> Either ConfigError ValidConfig
validateConfig config = do
  traverse_ validatePreset (configSoundPresets config)
  pure (ValidConfig config)
  where
    validatePreset :: SoundPreset -> Either ConfigError ()
    validatePreset preset =
      traverse_ (validateKeyConfig preset) (presetKeyConfigs preset)

    validateKeyConfig :: SoundPreset -> KeyConfig -> Either ConfigError ()
    validateKeyConfig preset keyConfig =
      case keyConfigFiles keyConfig of
        [] -> Left (NoAudioFiles (Text.unpack (presetName preset)))
        _ -> Right ()

-- | Find the config file Bearilo should use.
resolveConfigPath :: Maybe FilePath -> IO (Either ConfigError FilePath)
resolveConfigPath (Just path) = do
  exists <- doesFileExist path
  pure $
    if exists
      then Right path
      else Left (ConfigPathMissing path)
resolveConfigPath Nothing = do
  configDir <- getXdgDirectory XdgConfig ""
  firstExisting
    [ configDir </> "bearilo.toml",
      configDir </> "daktilo" </> "bearilo.toml",
      configDir </> "daktilo" </> "config"
    ]
  where
    firstExisting :: [FilePath] -> IO (Either ConfigError FilePath)
    firstExisting [] = pure (Left (ConfigPathMissing "bearilo.toml"))
    firstExisting (path : rest) = do
      exists <- doesFileExist path
      if exists then pure (Right path) else firstExisting rest

-- | Merge CLI options into a parsed config.
mergeConfig :: CliOptions -> Config -> Either ConfigError AppConfig
mergeConfig options config = do
  let configWithNoSurprises =
        applyNoSurprises (cliNoSurprises options) config
      noSurprises =
        configNoSurprises configWithNoSurprises
  presets <- selectPresets configWithNoSurprises (cliPresets options)

  pure
    AppConfig
      { appPresets = presets,
        appDevice = cliDevice options,
        appNoSurprises = noSurprises,
        appVolumeVariation = cliVolumeVariation options,
        appTempoVariation = cliTempoVariation options
      }

-- | Select requested presets, or the default preset when none are named.
selectPresets :: Config -> [PresetName] -> Either ConfigError [SoundPreset]
selectPresets config [] =
  (: []) <$> selectDefaultPreset config
selectPresets config names =
  traverse selectPreset names
  where
    selectPreset name =
      case resolveHiddenPreset (configNoSurprises config) name <|> find ((== name) . presetName) (configSoundPresets config) of
        Just preset -> Right preset
        Nothing -> Left (PresetNotFound (Text.unpack name))

-- | Find the configured default preset.
selectDefaultPreset :: Config -> Either ConfigError SoundPreset
selectDefaultPreset config =
  case find ((== Text.pack "default") . presetName) (configSoundPresets config) of
    Just preset -> Right preset
    Nothing -> Left (PresetNotFound "default")

-- | Apply the CLI no-surprises switch to config.
applyNoSurprises :: Bool -> Config -> Config
applyNoSurprises enabled config =
  config {configNoSurprises = enabled || configNoSurprises config}

-- | Return Bearilo's hidden preset when it is allowed.
resolveHiddenPreset :: Bool -> PresetName -> Maybe SoundPreset
resolveHiddenPreset noSurprises name
  | name == Text.pack "ak47" = Just hiddenPreset
  | name == Text.pack "__random_surprise__" && not noSurprises = Just hiddenPreset
  | otherwise = Nothing
  where
    hiddenPreset =
      SoundPreset
        { presetName = Text.pack "ak47",
          presetDisabledKeys = [],
          presetVariation = Nothing,
          presetKeyConfigs =
            [ KeyConfig
                { keyConfigEvent = KeyPress,
                  keyConfigKeys = Text.pack ".*",
                  keyConfigFiles =
                    [ AudioFile {audioFilePath = "mbox10.mp3", audioFileVolume = Nothing},
                      AudioFile {audioFilePath = "mbox11.mp3", audioFileVolume = Nothing},
                      AudioFile {audioFilePath = "mbox9.mp3", audioFileVolume = Nothing}
                    ],
                  keyConfigStrategy = Just Random,
                  keyConfigVariation = Nothing
                }
            ]
        }

-- | Parse a config event name.
parseKeyEvent :: Text -> Either ConfigError KeyEvent
parseKeyEvent value
  | value == Text.pack "press" = Right KeyPress
  | value == Text.pack "release" = Right KeyRelease
  | otherwise = Left (InvalidKeyEvent (Text.unpack value))

-- | Parse a playback strategy name.
parsePlaybackStrategy :: Text -> Either ConfigError PlaybackStrategy
parsePlaybackStrategy value
  | value == Text.pack "random" = Right Random
  | value == Text.pack "sequential" = Right Sequential
  | otherwise = Left (InvalidPlaybackStrategy (Text.unpack value))

decodeDocument :: TomlDocument -> Either ConfigError Config
decodeDocument document = do
  noSurprises <- optionalBool False (tomlTopLevel document) (Text.pack "no_surprises")
  presets <- traverse decodePreset (tomlPresets document)
  pure
    Config
      { configSoundPresets = presets,
        configNoSurprises = noSurprises
      }

decodePreset :: [(Text, TomlValue)] -> Either ConfigError SoundPreset
decodePreset fields = do
  name <- requiredString (Text.pack "sound_preset") fields (Text.pack "name")
  keyConfigs <-
    requiredArray (Text.pack "sound_preset") fields (Text.pack "key_config")
      >>= traverse (asInlineTable (Text.pack "key_config"))
      >>= traverse decodeKeyConfig
  disabledKeys <-
    optionalArray [] fields (Text.pack "disabled_keys")
      >>= traverse (asString (Text.pack "disabled_keys"))
  variation <- optionalVariation fields (Text.pack "variation")
  pure
    SoundPreset
      { presetName = name,
        presetKeyConfigs = keyConfigs,
        presetDisabledKeys = disabledKeys,
        presetVariation = variation
      }

decodeKeyConfig :: [(Text, TomlValue)] -> Either ConfigError KeyConfig
decodeKeyConfig fields = do
  eventText <- requiredString (Text.pack "key_config") fields (Text.pack "event")
  event <- parseKeyEvent eventText
  keys <- requiredString (Text.pack "key_config") fields (Text.pack "keys")
  files <-
    requiredArray (Text.pack "key_config") fields (Text.pack "files")
      >>= traverse (asInlineTable (Text.pack "files"))
      >>= traverse decodeAudioFile
  strategy <- optionalTextField fields (Text.pack "strategy") >>= traverse parsePlaybackStrategy
  variation <- optionalVariation fields (Text.pack "variation")
  pure
    KeyConfig
      { keyConfigEvent = event,
        keyConfigKeys = keys,
        keyConfigFiles = files,
        keyConfigStrategy = strategy,
        keyConfigVariation = variation
      }

decodeAudioFile :: [(Text, TomlValue)] -> Either ConfigError AudioFile
decodeAudioFile fields = do
  path <- requiredString (Text.pack "file") fields (Text.pack "path")
  volume <- optionalNumber fields (Text.pack "volume")
  pure
    AudioFile
      { audioFilePath = Text.unpack path,
        audioFileVolume = volume
      }

optionalVariation :: [(Text, TomlValue)] -> Text -> Either ConfigError (Maybe SoundVariation)
optionalVariation fields key =
  case lookup key fields of
    Nothing -> Right Nothing
    Just value -> Just <$> (asInlineTable key value >>= decodeSoundVariation)

decodeSoundVariation :: [(Text, TomlValue)] -> Either ConfigError SoundVariation
decodeSoundVariation fields = do
  volume <- optionalVariationRange fields (Text.pack "volume")
  tempo <- optionalVariationRange fields (Text.pack "tempo")
  pure
    SoundVariation
      { soundVariationVolume = volume,
        soundVariationTempo = tempo
      }

optionalVariationRange :: [(Text, TomlValue)] -> Text -> Either ConfigError (Maybe VariationRange)
optionalVariationRange fields key =
  case lookup key fields of
    Nothing -> Right Nothing
    Just (TomlArray [TomlNumber value]) ->
      Right (Just VariationRange {variationDown = value, variationUp = value})
    Just (TomlArray [TomlNumber down, TomlNumber up]) ->
      Right (Just VariationRange {variationDown = down, variationUp = up})
    Just _ -> Left (InvalidConfigField ("expected numeric range for " <> Text.unpack key))

requiredString :: Text -> [(Text, TomlValue)] -> Text -> Either ConfigError Text
requiredString context fields key =
  case lookup key fields of
    Nothing -> Left (MissingConfigField (Text.unpack context <> "." <> Text.unpack key))
    Just value -> asString key value

requiredArray :: Text -> [(Text, TomlValue)] -> Text -> Either ConfigError [TomlValue]
requiredArray context fields key =
  case lookup key fields of
    Nothing -> Left (MissingConfigField (Text.unpack context <> "." <> Text.unpack key))
    Just value -> asArray key value

optionalArray :: [TomlValue] -> [(Text, TomlValue)] -> Text -> Either ConfigError [TomlValue]
optionalArray fallback fields key =
  case lookup key fields of
    Nothing -> Right fallback
    Just value -> asArray key value

optionalBool :: Bool -> [(Text, TomlValue)] -> Text -> Either ConfigError Bool
optionalBool fallback fields key =
  case lookup key fields of
    Nothing -> Right fallback
    Just (TomlBool value) -> Right value
    Just _ -> Left (InvalidConfigField ("expected boolean for " <> Text.unpack key))

optionalNumber :: [(Text, TomlValue)] -> Text -> Either ConfigError (Maybe Double)
optionalNumber fields key =
  case lookup key fields of
    Nothing -> Right Nothing
    Just (TomlNumber value) -> Right (Just value)
    Just _ -> Left (InvalidConfigField ("expected number for " <> Text.unpack key))

optionalTextField :: [(Text, TomlValue)] -> Text -> Either ConfigError (Maybe Text)
optionalTextField fields key =
  case lookup key fields of
    Nothing -> Right Nothing
    Just value -> Just <$> asString key value

asString :: Text -> TomlValue -> Either ConfigError Text
asString _ (TomlString value) = Right value
asString key _ = Left (InvalidConfigField ("expected string for " <> Text.unpack key))

asArray :: Text -> TomlValue -> Either ConfigError [TomlValue]
asArray _ (TomlArray values) = Right values
asArray key _ = Left (InvalidConfigField ("expected array for " <> Text.unpack key))

asInlineTable :: Text -> TomlValue -> Either ConfigError [(Text, TomlValue)]
asInlineTable _ (TomlInlineTable fields) = Right fields
asInlineTable key _ = Left (InvalidConfigField ("expected inline table for " <> Text.unpack key))

tomlDocument :: Parser TomlDocument
tomlDocument = do
  sc
  items <- many (tomlItem <* sc)
  eof
  pure (buildDocument items)

buildDocument :: [TomlItem] -> TomlDocument
buildDocument items =
  finalize (foldl addItem ([], Nothing, []) items)
  where
    addItem (topLevel, currentPreset, presets) item =
      case item of
        TomlPresetHeader ->
          (topLevel, Just [], maybe presets (: presets) currentPreset)
        TomlAssignment key value ->
          case currentPreset of
            Nothing -> ((key, value) : topLevel, Nothing, presets)
            Just preset -> (topLevel, Just ((key, value) : preset), presets)

    finalize (topLevel, currentPreset, presets) =
      TomlDocument
        { tomlTopLevel = reverse topLevel,
          tomlPresets = reverse (maybe presets (: presets) currentPreset)
        }

tomlItem :: Parser TomlItem
tomlItem =
  try (TomlPresetHeader <$ tomlPresetHeader)
    <|> (TomlAssignment <$> tomlKey <* symbol "=" <*> tomlValue)

tomlPresetHeader :: Parser ()
tomlPresetHeader = do
  void (symbol "[[")
  void (symbol "sound_preset")
  void (symbol "]]")

tomlValue :: Parser TomlValue
tomlValue =
  choice
    [ TomlString <$> tomlString,
      TomlBool <$> tomlBool,
      TomlArray <$> tomlArray,
      TomlInlineTable <$> tomlInlineTable,
      TomlNumber <$> tomlNumber
    ]

tomlKey :: Parser Text
tomlKey =
  lexeme $
    Text.pack <$> many1 (alphaNum <|> char '_' <|> char '-')

tomlString :: Parser Text
tomlString =
  lexeme $
    Text.pack <$> (char '"' *> many stringChar <* char '"')
  where
    stringChar =
      escapedChar <|> noneOf ['"', '\\']

    escapedChar = do
      void (char '\\')
      choice
        [ '\n' <$ char 'n',
          '\t' <$ char 't',
          '\r' <$ char 'r',
          '"' <$ char '"',
          '\\' <$ char '\\'
        ]

tomlBool :: Parser Bool
tomlBool =
  lexeme $
    try (True <$ string "true")
      <|> try (False <$ string "false")

tomlNumber :: Parser Double
tomlNumber =
  lexeme $ do
    sign <- optionMaybe (char '-')
    whole <- many1 digit
    fractional <- optionMaybe ((:) <$> char '.' <*> many1 digit)
    let raw = maybe "" pure sign <> whole <> fromMaybe "" fractional
    pure (read raw)

tomlArray :: Parser [TomlValue]
tomlArray =
  symbol "[" *> sepEndBy tomlValue (symbol ",") <* symbol "]"

tomlInlineTable :: Parser [(Text, TomlValue)]
tomlInlineTable =
  symbol "{" *> sepEndBy tomlPair (symbol ",") <* symbol "}"

tomlPair :: Parser (Text, TomlValue)
tomlPair =
  (,) <$> tomlKey <* symbol "=" <*> tomlValue

symbol :: String -> Parser String
symbol = lexeme . string

lexeme :: Parser a -> Parser a
lexeme parser = parser <* sc

sc :: Parser ()
sc =
  skipMany (void (oneOf " \t\r\n") <|> lineComment)

lineComment :: Parser ()
lineComment = do
  void (char '#')
  void (many (noneOf "\n"))
  void (optionMaybe (char '\n'))
