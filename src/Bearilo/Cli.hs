-- | Command line parsing for Bearilo.
module Bearilo.Cli
  ( CliCommand (..),
    CliEnv (..),
    CliError (..),
    CliOptions (..),
    cliCommand,
    cliEnvFromPairs,
    defaultCliEnv,
    defaultCliOptions,
    mergeCliEnv,
    parseCli,
    parseCliPure,
    readCliEnv,
    variationFromCliValues,
  )
where

import Bearilo.Output (beariloHelpText)
import Bearilo.Types (PresetName, VariationRange (..))
import Bearilo.Version (beariloVersion)
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Options.Applicative
import Options.Applicative.Help.Pretty qualified as Pretty
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | The command selected by parsed flags.
data CliCommand
  = CliRun
  | CliVersion
  | CliInit
  | CliListPresets
  | CliListDevices
  deriving stock (Eq, Show)

-- | Parsed command line options.
data CliOptions = CliOptions
  { cliShowVersion :: Bool,
    cliInit :: Bool,
    cliListPresets :: Bool,
    cliListDevices :: Bool,
    cliVerbose :: Int,
    cliPresets :: [PresetName],
    cliDevice :: Maybe Text,
    cliConfigPath :: Maybe FilePath,
    cliNoSurprises :: Bool,
    cliVolumeVariation :: Maybe VariationRange,
    cliTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

-- | Options that can come from environment variables.
data CliEnv = CliEnv
  { envVerbose :: Maybe Int,
    envPresets :: [PresetName],
    envDevice :: Maybe Text,
    envConfigPath :: Maybe FilePath,
    envVolumeVariation :: Maybe VariationRange,
    envTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

-- | CLI parser failures we keep as values in tests.
data CliError
  = CliParseError String
  | CliInvalidVariation String
  deriving stock (Eq, Show)

data RawCliOptions = RawCliOptions
  { rawShowVersion :: Bool,
    rawInit :: Bool,
    rawListPresets :: Bool,
    rawListDevices :: Bool,
    rawVerbose :: Int,
    rawPresets :: [PresetName],
    rawDevice :: Maybe Text,
    rawConfigPath :: Maybe FilePath,
    rawNoSurprises :: Bool,
    rawVolumeVariation :: [Double],
    rawTempoVariation :: [Double]
  }
  deriving stock (Eq, Show)

-- | Default options before flags or environment values are applied.
defaultCliOptions :: CliOptions
defaultCliOptions =
  CliOptions
    { cliShowVersion = False,
      cliInit = False,
      cliListPresets = False,
      cliListDevices = False,
      cliVerbose = 0,
      cliPresets = [],
      cliDevice = Nothing,
      cliConfigPath = Nothing,
      cliNoSurprises = False,
      cliVolumeVariation = Nothing,
      cliTempoVariation = Nothing
    }

-- | Empty environment-derived options.
defaultCliEnv :: CliEnv
defaultCliEnv =
  CliEnv
    { envVerbose = Nothing,
      envPresets = [],
      envDevice = Nothing,
      envConfigPath = Nothing,
      envVolumeVariation = Nothing,
      envTempoVariation = Nothing
    }

-- | Parse the real process arguments and environment.
parseCli :: IO CliOptions
parseCli = do
  rawOptions <- execParser (cliParserInfo True)
  env <- readCliEnv
  case rawToCliOptions rawOptions of
    Left err -> ioError (userError (show err))
    Right options -> pure (mergeCliEnv env options)

-- | Parse CLI args without touching IO.
parseCliPure :: [String] -> Either CliError CliOptions
parseCliPure args =
  case execParserPure defaultPrefs (cliParserInfo False) args of
    Success rawOptions -> rawToCliOptions rawOptions
    Failure failure ->
      let (message, _) = renderFailure failure "bearilo"
       in Left (CliParseError message)
    CompletionInvoked _ ->
      Left (CliParseError "completion invoked")

-- | Read Bearilo's supported environment variables.
readCliEnv :: IO CliEnv
readCliEnv = do
  pairs <-
    traverse
      ( \name -> do
          envValue <- lookupEnv name
          pure ((name,) <$> envValue)
      )
      [ "VERBOSE",
        "PRESET",
        "DAKTILO_DEVICE",
        "DAKTILO_CONFIG",
        "DAKTILO_VOLUME",
        "DAKTILO_TEMPO"
      ]

  pure (cliEnvFromPairs (catMaybes pairs))

-- | Build env options from name/value pairs.
cliEnvFromPairs :: [(String, String)] -> CliEnv
cliEnvFromPairs pairs =
  CliEnv
    { envVerbose = lookup "VERBOSE" pairs >>= readMaybe,
      envPresets = maybe [] ((: []) . Text.pack) (lookup "PRESET" pairs),
      envDevice = Text.pack <$> lookup "DAKTILO_DEVICE" pairs,
      envConfigPath = lookup "DAKTILO_CONFIG" pairs,
      envVolumeVariation = lookup "DAKTILO_VOLUME" pairs >>= eitherToMaybe . variationFromText,
      envTempoVariation = lookup "DAKTILO_TEMPO" pairs >>= eitherToMaybe . variationFromText
    }
  where
    eitherToMaybe (Right parsedValue) = Just parsedValue
    eitherToMaybe (Left _) = Nothing

-- | Merge environment values without erasing explicit CLI options.
mergeCliEnv :: CliEnv -> CliOptions -> CliOptions
mergeCliEnv env options =
  options
    { cliVerbose =
        if cliVerbose options == 0
          then fromMaybe 0 (envVerbose env)
          else cliVerbose options,
      cliPresets =
        if null (cliPresets options)
          then envPresets env
          else cliPresets options,
      cliDevice = cliDevice options <|> envDevice env,
      cliConfigPath = cliConfigPath options <|> envConfigPath env,
      cliVolumeVariation = cliVolumeVariation options <|> envVolumeVariation env,
      cliTempoVariation = cliTempoVariation options <|> envTempoVariation env
    }

-- | Work out which command branch should run.
cliCommand :: CliOptions -> CliCommand
cliCommand options
  | cliShowVersion options = CliVersion
  | cliInit options = CliInit
  | cliListPresets options = CliListPresets
  | cliListDevices options = CliListDevices
  | otherwise = CliRun

-- | Turn one or two variation values into a range.
variationFromCliValues :: [Double] -> Either String VariationRange
variationFromCliValues [amount] =
  Right VariationRange {variationDown = amount, variationUp = amount}
variationFromCliValues [down, up] =
  Right VariationRange {variationDown = down, variationUp = up}
variationFromCliValues _ =
  Left "expected one or two variation values"

cliParserInfo :: Bool -> ParserInfo RawCliOptions
cliParserInfo useColor =
  info
    (helper <*> rawCliParser)
    ( fullDesc
        <> headerDoc (Just (Pretty.vcat (map Pretty.pretty (lines (beariloHelpText useColor)))))
    )

rawCliParser :: Parser RawCliOptions
rawCliParser =
  RawCliOptions
    <$> switch (long "version" <> short 'v' <> help ("Show version (" <> "bearilo " <> beariloVersion <> ")"))
    <*> switch (long "init" <> help "Write default config")
    <*> switch (long "list-presets" <> help "List presets")
    <*> switch (long "list-devices" <> help "List output devices")
    -- -v is version, so verbose keeps Daktilo's capital -V spelling.
    <*> (length <$> many (flag' () (long "verbose" <> short 'V' <> help "Increase verbosity")))
    <*> many (Text.pack <$> strOption (long "preset" <> metavar "PRESET" <> help "Select preset"))
    <*> optional (Text.pack <$> strOption (long "device" <> metavar "DEVICE" <> help "Select output device"))
    <*> optional (strOption (long "config" <> metavar "PATH" <> help "Use config file"))
    <*> switch (long "no-surprises" <> internal)
    <*> many (option auto (long "variate-volume" <> metavar "VALUE" <> help "Apply volume variation"))
    <*> many (option auto (long "variate-tempo" <> metavar "VALUE" <> help "Apply tempo variation"))

rawToCliOptions :: RawCliOptions -> Either CliError CliOptions
rawToCliOptions rawOptions = do
  volumeVariation <- optionalVariation (rawVolumeVariation rawOptions)
  tempoVariation <- optionalVariation (rawTempoVariation rawOptions)
  pure
    CliOptions
      { cliShowVersion = rawShowVersion rawOptions,
        cliInit = rawInit rawOptions,
        cliListPresets = rawListPresets rawOptions,
        cliListDevices = rawListDevices rawOptions,
        cliVerbose = rawVerbose rawOptions,
        cliPresets = rawPresets rawOptions,
        cliDevice = rawDevice rawOptions,
        cliConfigPath = rawConfigPath rawOptions,
        cliNoSurprises = rawNoSurprises rawOptions,
        cliVolumeVariation = volumeVariation,
        cliTempoVariation = tempoVariation
      }
  where
    optionalVariation [] = Right Nothing
    optionalVariation values =
      case variationFromCliValues values of
        Left err -> Left (CliInvalidVariation err)
        Right range -> Right (Just range)

variationFromText :: String -> Either String VariationRange
variationFromText rawVariationText =
  case traverse readMaybe (variationWords rawVariationText) of
    Nothing -> Left "expected numeric variation values"
    Just values -> variationFromCliValues values
  where
    variationWords =
      words . map commaToSpace

    commaToSpace ',' = ' '
    commaToSpace char = char
