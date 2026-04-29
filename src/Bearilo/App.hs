-- | Start and wire Bearilo's runtime.
module Bearilo.App
  ( Runtime (..),
    listPresets,
    listPresetsWithColor,
    run,
    runCommand,
    runWith,
  )
where

import Bearilo.Assets (defaultConfigText, lookupEmbeddedSound)
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Cli
import Bearilo.Config (mergeConfig, parseConfig, resolveConfigPath)
import Bearilo.Error (AppError (..), renderError)
import Bearilo.Input (classifyKeyEvent, emptyKeyMemory, shouldPlayEvent)
import Bearilo.Logger (LogMessageLevel (..), Logger (..), logDebug, logInfo, logTrace, logWarn, shouldLog, verbosityToLevel)
import Bearilo.Os (withKeyListener)
import Bearilo.Output (renderChoiceKeyConfig, renderConfigSummary, renderDeviceList, renderPlaybackParams, renderPresetList)
import Bearilo.Types
import Bearilo.Version (beariloVersion)
import Control.Concurrent (threadDelay)
import Control.Monad (forever, when)
import Data.Foldable (traverse_)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (intercalate)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time (UTCTime, getCurrentTime)
import System.IO qualified as IO

-- | Everything App needs from the outside world.
data Runtime = Runtime
  { runtimeParseCli :: IO (Either AppError CliOptions),
    runtimeReadConfig :: Logger -> CliOptions -> IO (Either AppError Config),
    runtimeWriteFile :: FilePath -> String -> IO (),
    runtimeOutput :: String -> IO (),
    runtimeLogOutput :: String -> IO (),
    runtimeCurrentTime :: IO UTCTime,
    runtimeListDevices :: IO (Either AppError [OutputDevice]),
    runtimeWithAudio :: (AudioEngine -> IO (Either AppError ())) -> IO (Either AppError ()),
    runtimeListen :: Logger -> (KeyEvent -> IO ()) -> IO (Either AppError ()),
    runtimePlay :: AudioEngine -> SoundChoice -> IO (Either AppError ()),
    runtimeUseColor :: Bool
  }

-- | Start Bearilo.
--
-- This wires config, logging, keyboard events, and audio together.
run :: IO ()
run = do
  result <- runWith defaultRuntime
  case result of
    Right () -> pure ()
    Left err -> IO.hPutStrLn IO.stderr (renderError err)

-- | Run Bearilo with an injected runtime.
runWith :: Runtime -> IO (Either AppError ())
runWith runtime = do
  parsed <- runtimeParseCli runtime
  case parsed of
    Left err -> pure (Left err)
    Right options -> do
      let logger = loggerFor runtime options
      logTrace logger ("CLI options after parse: " <> show options)
      case cliCommand options of
        CliVersion -> runCommandWithLogger runtime logger options
        _ -> do
          logInfo logger "Starting..."
          runCommandWithLogger runtime logger options

-- | Run one parsed command.
runCommand :: Runtime -> CliOptions -> IO (Either AppError ())
runCommand runtime options =
  runCommandWithLogger runtime (loggerFor runtime options) options

runCommandWithLogger :: Runtime -> Logger -> CliOptions -> IO (Either AppError ())
runCommandWithLogger runtime logger options =
  case cliCommand options of
    CliVersion ->
      Right <$> runtimeOutput runtime ("bearilo " <> beariloVersion <> "\n")
    CliInit -> do
      logInfo logger "Saving the configuration file to \"bearilo.toml\""
      runtimeWriteFile runtime "bearilo.toml" (Text.unpack defaultConfigText)
      pure (Right ())
    CliListPresets -> do
      configResult <- readConfig
      case configResult of
        Left err -> pure (Left err)
        Right config -> do
          logInfo logger "Available presets:"
          Right <$> runtimeOutput runtime (listPresetsWithColor (runtimeUseColor runtime) config)
    CliListDevices -> do
      devices <- runtimeListDevices runtime
      case devices of
        Left err -> pure (Left err)
        Right outputDevices -> do
          logInfo logger "Available devices:"
          logDebug logger ("Number of output devices found: " <> show (length outputDevices))
          Right <$> runtimeOutput runtime (renderDeviceList (runtimeUseColor runtime) outputDevices)
    CliRun -> do
      configResult <- readConfig
      case configResult of
        Left err -> pure (Left err)
        Right config -> do
          when (null (cliPresets options)) $
            logWarn logger "No preset specified, using the default preset."
          case appConfigFromCli options config of
            Left err -> pure (Left err)
            Right appConfig -> do
              logAppConfig logger appConfig
              logOutputDevicesForDebug runtime logger
              runListener logger runtime appConfig
  where
    readConfig =
      runtimeReadConfig runtime logger options

-- | Render preset rows without color.
listPresets :: Config -> String
listPresets =
  listPresetsWithColor False

-- | Render preset rows, optionally coloring the header.
listPresetsWithColor :: Bool -> Config -> String
listPresetsWithColor useColor config =
  renderPresetList useColor (configSoundPresets config)

defaultRuntime :: Runtime
defaultRuntime =
  Runtime
    { runtimeParseCli = fmap Right parseCli,
      runtimeReadConfig = defaultReadConfig,
      runtimeWriteFile = writeFile,
      runtimeOutput = putStr,
      runtimeLogOutput = IO.hPutStrLn IO.stderr,
      runtimeCurrentTime = getCurrentTime,
      runtimeListDevices = defaultListDevices,
      runtimeWithAudio = defaultWithAudio,
      runtimeListen = defaultListen,
      runtimePlay = defaultPlay,
      runtimeUseColor = True
    }

loggerFor :: Runtime -> CliOptions -> Logger
loggerFor runtime options =
  Logger
    { loggerLevel = verbosityToLevel (cliVerbose options),
      loggerNow = runtimeCurrentTime runtime,
      loggerOutput = runtimeLogOutput runtime,
      loggerUseColor = runtimeUseColor runtime
    }

defaultReadConfig :: Logger -> CliOptions -> IO (Either AppError Config)
defaultReadConfig logger options =
  case cliConfigPath options of
    Just path -> do
      logDebug logger ("Config path specified: " <> path)
      resolved <- resolveConfigPath (Just path)
      case resolved of
        Right resolvedPath -> do
          logDebug logger ("Config path chosen: " <> resolvedPath)
          readConfigFile resolvedPath
        Left err -> pure (Left (AppConfigError err))
    Nothing -> do
      logDebug logger "No config path specified; checking default locations."
      resolved <- resolveConfigPath Nothing
      case resolved of
        Right path -> do
          logDebug logger ("Config path chosen: " <> path)
          readConfigFile path
        Left _ -> do
          logWarn logger "Using the default configuration (run with `--init` to save it to a file)."
          logDebug logger "Config source: embedded default"
          parseConfigResult "embedded default" defaultConfigText
  where
    readConfigFile path = do
      input <- TextIO.readFile path
      logDebug logger ("Config source: " <> path)
      parseConfigResult path input

    parseConfigResult sourceLabel input =
      case parseConfig input of
        Left err -> pure (Left (AppConfigError err))
        Right config -> do
          logDebug logger (renderConfigSummary (loggerUseColor logger) sourceLabel config)
          pure (Right config)

defaultListDevices :: IO (Either AppError [OutputDevice])
defaultListDevices = do
  result <- listOutputDevices
  pure $
    case result of
      Left err -> Left (AppAudioError err)
      Right devices -> Right devices

defaultWithAudio :: (AudioEngine -> IO (Either AppError ())) -> IO (Either AppError ())
defaultWithAudio action = do
  result <- withAudio action
  pure $
    case result of
      Left err -> Left (AppAudioError err)
      Right inner -> inner

defaultListen :: Logger -> (KeyEvent -> IO ()) -> IO (Either AppError ())
defaultListen logger callback = do
  result <-
    withKeyListener
      handleRawEvent
      (forever (threadDelay maxBound))
  pure $
    case result of
      Left err -> Left (AppOsHookError err)
      Right () -> Right ()
  where
    handleRawEvent rawEvent = do
      logTrace logger ("Raw key event received: " <> show rawEvent)
      case classifyKeyEvent rawEvent of
        Nothing ->
          logTrace logger "Classified key event: ignored"
        Just event -> do
          logTrace logger ("Classified key event: " <> show event)
          callback event

defaultPlay :: AudioEngine -> SoundChoice -> IO (Either AppError ())
defaultPlay engine choice =
  case choiceSound choice of
    Nothing -> pure (Right ())
    Just sound -> do
      loaded <- loadSound engine (soundSource sound)
      case loaded of
        Left err -> pure (Left (AppAudioError err))
        Right loadedSound -> do
          played <-
            playSound
              engine
              loadedSound
              (effectivePlaybackParams choice)
          pure $
            case played of
              Left err -> Left (AppAudioError err)
              Right () -> Right ()
  where
    soundSource sound =
      SoundSource
        { sourcePath = soundPath sound,
          sourceBytes = soundBytes sound,
          sourceVolume = Nothing
        }

appConfigFromCli :: CliOptions -> Config -> Either AppError AppConfig
appConfigFromCli options config =
  case mergeConfig options config of
    Left err -> Left (AppConfigError err)
    Right appConfig -> Right appConfig

runListener :: Logger -> Runtime -> AppConfig -> IO (Either AppError ())
runListener logger runtime appConfig = do
  logDebug logger "SDL/mixer init starting."
  result <-
    runtimeWithAudio runtime $ \engine -> do
      logDebug logger "SDL/mixer init succeeded."
      logDebug logger ("Channel count / playback slots: " <> show (audioEnginePlaybackSlots engine))
      memoryRef <- newIORef emptyKeyMemory
      sequentialRef <- newIORef emptySequentialState
      runtimeListen runtime logger $ \event -> do
        logDebug logger ("Event: " <> eventLabel event)
        memory <- readIORef memoryRef
        sequentialState <- readIORef sequentialRef
        let (shouldPlay, nextMemory) = shouldPlayEvent memory event
        writeIORef memoryRef nextMemory
        when shouldPlay $
          logDebug logger ("Press suppressed: " <> eventLabel event)
        when shouldPlay $ do
          let (choices, nextSequentialState) = soundChoicesForEventWithState appConfig sequentialState event
          writeIORef sequentialRef nextSequentialState
          logEventDecision logger appConfig event choices
          traverse_ (playChoice engine) choices
  case result of
    Left (AppAudioError AudioInterrupted) ->
      pure ()
    Left err@(AppAudioError _) ->
      logWarn logger ("Audio backend failed: " <> renderError err)
    _ ->
      pure ()
  pure $
    case result of
      Left (AppAudioError AudioInterrupted) -> Right ()
      _ -> result
  where
    playChoice engine choice = do
      logChoice logger choice
      playResult <- runtimePlay runtime engine choice
      case playResult of
        Left err ->
          logWarn logger ("Playback failed: " <> renderError err)
        Right () ->
          logTrace logger "SDL play call result/channel: ok"

logAppConfig :: Logger -> AppConfig -> IO ()
logAppConfig logger appConfig = do
  logDebug logger ("Selected preset names: " <> intercalate "," selectedPresetNames)
  logDebug logger ("Number of presets selected: " <> show (length (appPresets appConfig)))
  logDebug logger ("Number of key configs loaded: " <> show keyConfigCount)
  traverse_ logPresetSoundCount (appPresets appConfig)
  logDebug logger ("Output device selected: " <> maybe "default" Text.unpack (appDevice appConfig))
  where
    selectedPresetNames =
      map (Text.unpack . presetName) (appPresets appConfig)

    keyConfigCount =
      sum (map (length . presetKeyConfigs) (appPresets appConfig))

    logPresetSoundCount preset =
      logDebug
        logger
        ( "Number of sounds loaded for preset "
            <> Text.unpack (presetName preset)
            <> ": "
            <> show (sum (map (length . keyConfigFiles) (presetKeyConfigs preset)))
        )

logOutputDevicesForDebug :: Runtime -> Logger -> IO ()
logOutputDevicesForDebug runtime logger =
  when (shouldLog (loggerLevel logger) MsgDebug) $ do
    devices <- runtimeListDevices runtime
    case devices of
      Left err ->
        logDebug logger ("Output device listing failed: " <> renderError err)
      Right outputDevices ->
        logDebug logger ("Number of output devices found: " <> show (length outputDevices))

logEventDecision :: Logger -> AppConfig -> KeyEvent -> [SoundChoice] -> IO ()
logEventDecision logger appConfig event choices = do
  when disabled $
    logDebug logger ("Disabled-key skip: " <> Text.unpack keyName)
  when (null choices && not disabled) $
    logDebug logger ("No matching key config: " <> eventLabel event)
  where
    keyName =
      keyNameForEvent event

    disabled =
      not (Text.null keyName)
        && any (elem keyName . presetDisabledKeys) (appPresets appConfig)

logChoice :: Logger -> SoundChoice -> IO ()
logChoice logger choice =
  case choiceSound choice of
    Nothing ->
      logTrace logger "Chosen file: none"
    Just sound -> do
      logDebug logger ("Key config: " <> renderChoiceKeyConfig choice)
      logDebug logger ("Playing: " <> soundPath sound)
      logTrace logger ("Embedded sound lookup " <> embeddedResult <> ": " <> soundPath sound)
      when (embeddedResult == "miss") $
        logTrace logger ("File path fallback attempted: " <> soundPath sound)
      logDebug logger (renderPlaybackParams (effectivePlaybackParams choice))
  where
    embeddedResult =
      case lookupEmbeddedSound . soundPath =<< choiceSound choice of
        Just _ -> "hit"
        Nothing -> "miss"

keyNameForEvent :: KeyEvent -> Text.Text
keyNameForEvent event =
  case event of
    KeyPressed keyName -> keyName
    KeyReleased keyName -> keyName
    KeyPress -> Text.empty
    KeyRelease -> Text.empty

eventLabel :: KeyEvent -> String
eventLabel event =
  case event of
    KeyPressed keyName -> "press " <> Text.unpack keyName
    KeyReleased keyName -> "release " <> Text.unpack keyName
    KeyPress -> "press"
    KeyRelease -> "release"
