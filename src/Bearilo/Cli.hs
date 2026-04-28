module Bearilo.Cli
  ( CliCommand (..),
    CliEnv (..),
    CliError (..),
    CliOptions (..),
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

import Bearilo.Types (PresetName, VariationRange (..))
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Options.Applicative
import System.Environment (getArgs, lookupEnv)
import Text.Read (readMaybe)

data CliCommand
  = CliRun
  | CliInit
  | CliListPresets
  | CliListDevices
  deriving stock (Eq, Show)

data CliOptions = CliOptions
  { cliCommand :: CliCommand,
    cliVerbose :: Int,
    cliPresets :: [PresetName],
    cliDevice :: Maybe Text,
    cliConfigPath :: Maybe FilePath,
    cliNoSurprises :: Bool,
    cliVolumeVariation :: Maybe VariationRange,
    cliTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

data CliEnv = CliEnv
  { envVerbose :: Maybe Int,
    envPresets :: [PresetName],
    envDevice :: Maybe Text,
    envConfigPath :: Maybe FilePath,
    envVolumeVariation :: Maybe VariationRange,
    envTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

data CliError
  = CliParseError String
  | CliInvalidVariation String
  deriving stock (Eq, Show)

data RawCliOptions = RawCliOptions
  { rawCommand :: CliCommand,
    rawVerbose :: Int,
    rawPresets :: [PresetName],
    rawDevice :: Maybe Text,
    rawConfigPath :: Maybe FilePath,
    rawNoSurprises :: Bool,
    rawVolumeVariation :: [Double],
    rawTempoVariation :: [Double]
  }
  deriving stock (Eq, Show)

defaultCliOptions :: CliOptions
defaultCliOptions =
  CliOptions
    { cliCommand = CliRun,
      cliVerbose = 0,
      cliPresets = [],
      cliDevice = Nothing,
      cliConfigPath = Nothing,
      cliNoSurprises = False,
      cliVolumeVariation = Nothing,
      cliTempoVariation = Nothing
    }

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

parseCli :: IO CliOptions
parseCli = do
  args <- getArgs
  env <- readCliEnv
  case parseCliPure args of
    Left err -> ioError (userError (show err))
    Right options -> pure (mergeCliEnv env options)

parseCliPure :: [String] -> Either CliError CliOptions
parseCliPure args =
  case execParserPure defaultPrefs cliParserInfo args of
    Success rawOptions -> rawToCliOptions rawOptions
    Failure failure ->
      let (message, _) = renderFailure failure "bearilo"
       in Left (CliParseError message)
    CompletionInvoked _ ->
      Left (CliParseError "completion invoked")

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

variationFromCliValues :: [Double] -> Either String VariationRange
variationFromCliValues [amount] =
  Right VariationRange {variationDown = amount, variationUp = amount}
variationFromCliValues [down, up] =
  Right VariationRange {variationDown = down, variationUp = up}
variationFromCliValues _ =
  Left "expected one or two variation values"

cliParserInfo :: ParserInfo RawCliOptions
cliParserInfo =
  info
    (helper <*> versionOption <*> rawCliParser)
    (fullDesc <> progDesc "Turn keyboard input into typewriter sound effects")
  where
    versionOption =
      infoOption "bearilo 0.5.1.2" (long "version" <> help "Show version")

rawCliParser :: Parser RawCliOptions
rawCliParser =
  RawCliOptions
    <$> commandParser
    <*> (length <$> many (flag' () (long "verbose" <> short 'v' <> help "Increase verbosity")))
    <*> many (Text.pack <$> strOption (long "preset" <> metavar "PRESET" <> help "Select preset"))
    <*> optional (Text.pack <$> strOption (long "device" <> metavar "DEVICE" <> help "Select output device"))
    <*> optional (strOption (long "config" <> metavar "PATH" <> help "Use config file"))
    <*> switch (long "no-surprises" <> internal)
    <*> many (option auto (long "variate-volume" <> metavar "VALUE" <> help "Apply volume variation"))
    <*> many (option auto (long "variate-tempo" <> metavar "VALUE" <> help "Apply tempo variation"))

commandParser :: Parser CliCommand
commandParser =
  flag' CliInit (long "init" <> help "Write default config")
    <|> flag' CliListPresets (long "list-presets" <> help "List presets")
    <|> flag' CliListDevices (long "list-devices" <> help "List output devices")
    <|> pure CliRun

rawToCliOptions :: RawCliOptions -> Either CliError CliOptions
rawToCliOptions rawOptions = do
  volumeVariation <- optionalVariation (rawVolumeVariation rawOptions)
  tempoVariation <- optionalVariation (rawTempoVariation rawOptions)
  pure
    CliOptions
      { cliCommand = rawCommand rawOptions,
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
