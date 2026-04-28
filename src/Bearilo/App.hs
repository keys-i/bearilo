module Bearilo.App
  ( Runtime (..),
    applyNoSurprises,
    listPresets,
    resolveHiddenPreset,
    run,
    runCommand,
    runWith,
    selectDefaultPreset,
    selectPresets,
    soundChoicesForEvent,
  )
where

import Bearilo.Assets (defaultConfigText)
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Cli
import Bearilo.Config (parseConfig, resolveConfigPath)
import Bearilo.Error (AppError (..), ConfigError (..), renderError)
import Bearilo.Input (classifyKeyEvent, emptyKeyMemory, shouldPlayEvent)
import Bearilo.Os (withKeyListener)
import Bearilo.Types
import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Monad (forever, void)
import Data.Foldable (traverse_)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (find, intercalate)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.IO qualified as IO

data Runtime = Runtime
  { runtimeParseCli :: IO (Either AppError CliOptions),
    runtimeReadConfig :: CliOptions -> IO (Either AppError Config),
    runtimeWriteFile :: FilePath -> String -> IO (),
    runtimeOutput :: String -> IO (),
    runtimeListDevices :: IO (Either AppError [OutputDevice]),
    runtimeListen :: (KeyEvent -> IO ()) -> IO (Either AppError ()),
    runtimePlay :: SoundChoice -> IO (Either AppError ())
  }

run :: IO ()
run = do
  result <- runWith defaultRuntime
  case result of
    Right () -> pure ()
    Left err -> IO.hPutStrLn IO.stderr (renderError err)

runWith :: Runtime -> IO (Either AppError ())
runWith runtime = do
  parsed <- runtimeParseCli runtime
  case parsed of
    Left err -> pure (Left err)
    Right options -> runCommand runtime options

runCommand :: Runtime -> CliOptions -> IO (Either AppError ())
runCommand runtime options =
  case cliCommand options of
    CliInit -> do
      runtimeWriteFile runtime "bearilo.toml" (Text.unpack defaultConfigText)
      pure (Right ())
    CliListPresets -> do
      configResult <- readConfig
      case configResult of
        Left err -> pure (Left err)
        Right config -> Right <$> runtimeOutput runtime (listPresets config)
    CliListDevices -> do
      devices <- runtimeListDevices runtime
      case devices of
        Left err -> pure (Left err)
        Right outputDevices ->
          Right <$> runtimeOutput runtime (unlines (map outputDeviceLabel outputDevices))
    CliRun -> do
      configResult <- readConfig
      case configResult of
        Left err -> pure (Left err)
        Right config ->
          case appConfigFromCli options (applyNoSurprises (cliNoSurprises options) config) of
            Left err -> pure (Left err)
            Right appConfig -> runListener runtime appConfig
  where
    readConfig =
      runtimeReadConfig runtime options

listPresets :: Config -> String
listPresets config =
  unlines
    ( "Preset\tEvent\tKeys\tFile"
        : [ Text.unpack (presetName preset)
              <> "\t"
              <> eventLabel (keyConfigEvent keyConfig)
              <> "\t"
              <> Text.unpack (keyConfigKeys keyConfig)
              <> "\t"
              <> intercalate "," (map audioFilePath (keyConfigFiles keyConfig))
            | preset <- configSoundPresets config,
              keyConfig <- presetKeyConfigs preset
          ]
    )
  where
    eventLabel KeyPress = "press"
    eventLabel KeyRelease = "release"
    eventLabel (KeyPressed _) = "press"
    eventLabel (KeyReleased _) = "release"

selectPresets :: Config -> [PresetName] -> Either AppError [SoundPreset]
selectPresets config [] =
  (: []) <$> selectDefaultPreset config
selectPresets config names =
  traverse selectPreset names
  where
    selectPreset name =
      case resolveHiddenPreset (configNoSurprises config) name <|> find ((== name) . presetName) (configSoundPresets config) of
        Just preset -> Right preset
        Nothing -> Left (AppConfigError (PresetNotFound (Text.unpack name)))

selectDefaultPreset :: Config -> Either AppError SoundPreset
selectDefaultPreset config =
  case find ((== Text.pack "default") . presetName) (configSoundPresets config) of
    Just preset -> Right preset
    Nothing -> Left (AppConfigError (PresetNotFound "default"))

applyNoSurprises :: Bool -> Config -> Config
applyNoSurprises enabled config =
  config {configNoSurprises = enabled || configNoSurprises config}

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

soundChoicesForEvent :: AppConfig -> KeyEvent -> [SoundChoice]
soundChoicesForEvent appConfig event =
  [ choice
    | preset <- appPresets appConfig,
      let choice = soundForEvent appConfig {appPresets = [preset]} event,
      choiceSound choice /= Nothing
  ]

defaultRuntime :: Runtime
defaultRuntime =
  Runtime
    { runtimeParseCli = fmap Right parseCli,
      runtimeReadConfig = defaultReadConfig,
      runtimeWriteFile = writeFile,
      runtimeOutput = putStr,
      runtimeListDevices = defaultListDevices,
      runtimeListen = defaultListen,
      runtimePlay = defaultPlay
    }

defaultReadConfig :: CliOptions -> IO (Either AppError Config)
defaultReadConfig options =
  case cliConfigPath options of
    Just path -> readConfigFile path
    Nothing -> do
      resolved <- resolveConfigPath Nothing
      case resolved of
        Right path -> readConfigFile path
        Left _ -> pure (parseConfigResult defaultConfigText)
  where
    readConfigFile path = do
      input <- TextIO.readFile path
      pure (parseConfigResult input)

    parseConfigResult input =
      case parseConfig input of
        Left err -> Left (AppConfigError err)
        Right config -> Right config

defaultListDevices :: IO (Either AppError [OutputDevice])
defaultListDevices = do
  result <- listOutputDevices
  pure $
    case result of
      Left err -> Left (AppAudioError err)
      Right devices -> Right devices

defaultListen :: (KeyEvent -> IO ()) -> IO (Either AppError ())
defaultListen callback = do
  result <-
    withKeyListener
      ( \rawEvent ->
          traverse_ callback (classifyKeyEvent rawEvent)
      )
      (forever (threadDelay maxBound))
  pure $
    case result of
      Left err -> Left (AppOsHookError err)
      Right () -> Right ()

defaultPlay :: SoundChoice -> IO (Either AppError ())
defaultPlay choice =
  case choiceSound choice of
    Nothing -> pure (Right ())
    Just sound -> do
      result <-
        withAudio $ \engine -> do
          loaded <- loadSound engine (soundSource sound)
          case loaded of
            Left err -> pure (Left err)
            Right loadedSound ->
              playSound
                engine
                loadedSound
                (choicePlaybackParams choice) {playbackVolume = soundVolume sound}
      pure $
        case result of
          Left err -> Left (AppAudioError err)
          Right (Left err) -> Left (AppAudioError err)
          Right (Right ()) -> Right ()
  where
    soundSource sound =
      SoundSource
        { sourcePath = soundPath sound,
          sourceBytes = soundBytes sound,
          sourceVolume = Just (soundVolume sound)
        }

appConfigFromCli :: CliOptions -> Config -> Either AppError AppConfig
appConfigFromCli options config = do
  presets <- selectPresets config (cliPresets options)
  pure
    AppConfig
      { appPresets = presets,
        appDevice = cliDevice options,
        appNoSurprises = cliNoSurprises options || configNoSurprises config,
        appVolumeVariation = cliVolumeVariation options,
        appTempoVariation = cliTempoVariation options
      }

runListener :: Runtime -> AppConfig -> IO (Either AppError ())
runListener runtime appConfig = do
  memoryRef <- newIORef emptyKeyMemory
  runtimeListen runtime $ \event -> do
    memory <- readIORef memoryRef
    let (shouldPlay, nextMemory) = shouldPlayEvent memory event
    writeIORef memoryRef nextMemory
    if shouldPlay
      then traverse_ (void . runtimePlay runtime) (soundChoicesForEvent appConfig event)
      else pure ()

outputDeviceLabel :: OutputDevice -> String
outputDeviceLabel OutputDevice {outputDeviceName = OutputDeviceName name} =
  name
