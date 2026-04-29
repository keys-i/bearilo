module AppSpec (spec) where

import Bearilo.App
import Bearilo.Assets (defaultConfigText)
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Cli
import Bearilo.Config (parseConfig, resolveHiddenPreset, selectPresets)
import Bearilo.Error
import Bearilo.Logger
import Bearilo.Output
  ( beariloAsciiArt,
    colorDebug,
    colorDeviceName,
    colorHeader,
    colorInfo,
    colorTarget,
    colorTimestamp,
    colorTrace,
    colorWarn,
    renderConfigSummary,
    renderDeviceList,
    renderPresetList,
  )
import Bearilo.Types
import Bearilo.Version (beariloVersion)
import Control.Monad (forM_)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (isInfixOf, isPrefixOf)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Time (UTCTime)

spec :: IO ()
spec = do
  testHelpPath
  testVerbosityToLevel
  testRenderLogLine
  testConfigSummaryRendering
  testVerboseCli
  testVersionAndHelpCli
  testActionFlagsKeepNormalOptions
  testShortOptionAliases
  testVersionCommandOutputsVersion
  testInitCli
  testListPresetsCli
  testListDevicesCli
  testHiddenNoSurprises
  testStartupLogsStarting
  testDefaultConfigLogsWarning
  testNoPresetLogsWarning
  testExplicitMissingConfigDoesNotLogFallback
  testNormalSoundPathPlaysDefaultSyntheticPress
  testPlaybackErrorIsLogged
  testUserInterruptCleanShutdown
  testDaktiloStyleReturnDebugLogs
  testDaktiloStyleFallbackDebugLogs
  testEnvPreset
  testEnvDevice
  testEnvConfig
  testEnvVolume
  testEnvTempo
  testDefaultPresetSelection
  testMissingPreset
  testListPresetsColumns
  testPresetTablePadding
  testPresetTableColor
  testEmbeddedPresetSections
  testDeviceListRendering
  testListPresetsSparks
  testListPresetsVpaul
  testListPresetsNoStandaloneSpark
  testDisabledKeyNoSound
  testDisabledKeyReleaseNoSound
  testDefaultReturnPressSelectsDing
  testDefaultReturnReleaseIsSilent
  testDefaultNormalKeyReleaseSelectsKeyup
  testFirstMatchingKeyConfigWins
  testReleasePlaybackSelected
  testRegexKeyMatch
  testMultiplePresetChoices
  testSequentialCycles
  testRandomReturnsConfiguredSound
  testAk47HiddenPreset
  testNoSurprisesDisablesRandomHiddenPreset

testHelpPath :: IO ()
testHelpPath =
  case parseCliPure ["--help"] of
    Left (CliParseError helpText) -> do
      assertBool "help contains usage" ("Usage:" `isInfixOf` helpText)
      assertEqual
        "help contains the new description once"
        1
        (countOccurrences "Turn your keyboard into a typewriter! 📇" helpText)
      assertBool
        "help contains author/powered line"
        ("Written by Keys-i -=[powered by bears]=-" `isInfixOf` helpText)
      assertBool "help contains ASCII art" (beariloAsciiArt `isInfixOf` helpText)
      assertBool "help contains bear face" ("ʕ•ᴥ•ʔ" `isInfixOf` helpText)
      assertBool "help does not contain old face" (not ("~~ ~~" `isInfixOf` helpText))
      assertBool
        "help does not contain old duplicated description"
        (not ("Turn keyboard input into typewriter sound effects." `isInfixOf` helpText))
      assertBool "help contains -V" ("-V" `isInfixOf` helpText)
      assertBool "help contains --verbose" ("--verbose" `isInfixOf` helpText)
      assertBool "help contains -v" ("-v" `isInfixOf` helpText)
      assertBool "help contains --version" ("--version" `isInfixOf` helpText)
      assertBool "hidden no-surprises is absent from help" (not ("--no-surprises" `isInfixOf` helpText))
    other -> error ("expected help parser path, got: " <> show other)

testVerbosityToLevel :: IO ()
testVerbosityToLevel = do
  assertEqual "default verbosity follows Daktilo INFO default" LogInfo (verbosityToLevel 0)
  assertEqual "-V keeps INFO logging" LogInfo (verbosityToLevel 1)
  assertEqual "-VV enables DEBUG logging" LogDebug (verbosityToLevel 2)
  assertEqual "-VVV enables TRACE logging" LogTrace (verbosityToLevel 3)
  assertEqual "high verbosity stays TRACE" LogTrace (verbosityToLevel 99)

testRenderLogLine :: IO ()
testRenderLogLine = do
  assertEqual
    "info log line format"
    "2026-04-28T09:06:28.980578Z  INFO bearilo: Starting..."
    (renderLogLine False fixedTime MsgInfo "Starting...")
  assertBool
    "debug level aligns with info"
    ("2026-04-28T09:06:28.980578Z DEBUG bearilo:" `isInfixOf` renderLogLine False fixedTime MsgDebug "Loaded")
  assertBool
    "warn log line contains WARN target"
    ("WARN bearilo:" `isInfixOf` renderLogLine False fixedTime MsgWarn "Using the default configuration...")
  assertBool
    "plain log line has no ANSI escapes"
    (not ("\ESC[" `isInfixOf` renderLogLine False fixedTime MsgInfo "Starting..."))
  assertBool
    "timestamp is grey when color is enabled"
    (colorTimestamp True "2026-04-28T09:06:28.980578Z" `isInfixOf` renderLogLine True fixedTime MsgInfo "Starting...")
  assertBool
    "bearilo target is grey when color is enabled"
    (colorTarget True "bearilo:" `isInfixOf` renderLogLine True fixedTime MsgInfo "Starting...")
  forM_
    [ ("INFO is bright bold green", MsgInfo, colorInfo, " INFO"),
      ("WARN is bright bold yellow", MsgWarn, colorWarn, " WARN"),
      ("DEBUG is bright bold purple", MsgDebug, colorDebug, "DEBUG"),
      ("TRACE is bright bold light blue", MsgTrace, colorTrace, "TRACE")
    ]
    $ \(label, level, colorLevel, renderedLevel) ->
      assertBool
        label
        (colorLevel True renderedLevel `isInfixOf` renderLogLine True fixedTime level "message")

testConfigSummaryRendering :: IO ()
testConfigSummaryRendering = do
  let output = renderConfigSummary False "embedded default" appConfigFixture

  assertBool "config summary includes source" ("source: embedded default" `isInfixOf` output)
  assertBool "config summary includes no_surprises" ("no_surprises: false" `isInfixOf` output)
  assertBool "config summary includes preset count" ("presets: 2" `isInfixOf` output)
  assertBool "config summary includes default preset" ("[default]" `isInfixOf` output)
  assertBool "config summary includes sparks preset" ("[sparks]" `isInfixOf` output)
  assertBool "config summary includes key rows" ("Key Press      .*        keydown.mp3" `isInfixOf` output)
  assertBool "config summary includes variation" ("variation volume ±0.10 tempo ±0.05" `isInfixOf` output)
  assertBool "config summary is not raw JSON" (not ("\"configSoundPresets\"" `isInfixOf` output))
  assertBool "config summary is not a derived Config dump" (not ("Config {" `isInfixOf` output))

testVerboseCli :: IO ()
testVerboseCli =
  forM_
    [ ("-V", ["-V"], 1),
      ("-VV", ["-VV"], 2),
      ("--verbose", ["--verbose"], 1)
    ]
    $ \(label, args, expected) ->
      assertCliVerbose label expected args

testVersionAndHelpCli :: IO ()
testVersionAndHelpCli = do
  forM_
    [ ("-v", ["-v"]),
      ("--version", ["--version"])
    ]
    $ \(label, args) ->
      assertCliCommand label CliVersion args

  forM_
    [ ("-h", ["-h"]),
      ("--help", ["--help"])
    ]
    $ \(label, args) ->
      case parseCliPure args of
        Left (CliParseError helpText) ->
          assertBool (label <> " returns help") ("Usage:" `isInfixOf` helpText)
        other -> error ("expected help parser path, got: " <> show other)

testActionFlagsKeepNormalOptions :: IO ()
testActionFlagsKeepNormalOptions = do
  case parseCliPure ["--init", "--config", "x.toml"] of
    Right options -> do
      assertEqual "init action parses" True (cliInit options)
      assertEqual "init keeps config" (Just "x.toml") (cliConfigPath options)
    other -> error ("expected init parse success, got: " <> show other)

  case parseCliPure ["--list-presets", "--config", "x.toml"] of
    Right options -> do
      assertEqual "list-presets action parses" True (cliListPresets options)
      assertEqual "list-presets keeps config" (Just "x.toml") (cliConfigPath options)
    other -> error ("expected list-presets parse success, got: " <> show other)

  case parseCliPure ["--list-devices", "--device", "BuiltIn"] of
    Right options -> do
      assertEqual "list-devices action parses" True (cliListDevices options)
      assertEqual "list-devices keeps device" (Just "BuiltIn") (cliDevice options)
    other -> error ("expected list-devices parse success, got: " <> show other)

testShortOptionAliases :: IO ()
testShortOptionAliases =
  case parseCliPure ["-i", "-p", "vpaul", "-d", "BuiltIn", "-c", "x.toml"] of
    Right options -> do
      assertEqual "short init parses" True (cliInit options)
      assertEqual "short preset parses" ["vpaul"] (cliPresets options)
      assertEqual "short device parses" (Just "BuiltIn") (cliDevice options)
      assertEqual "short config parses" (Just "x.toml") (cliConfigPath options)
    other -> error ("expected short option parse success, got: " <> show other)

testVersionCommandOutputsVersion :: IO ()
testVersionCommandOutputsVersion = do
  outputRef <- newIORef []
  result <-
    runWith
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions {cliShowVersion = True}),
          runtimeReadConfig = readConfigFixture,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \line -> modifyIORef' outputRef (<> [line]),
          runtimeLogOutput = \_ -> pure (),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ _ -> pure (Right ()),
          runtimePlay = \_ _ -> pure (Right ()),
          runtimeUseColor = False
        }
  output <- readIORef outputRef
  assertEqual "version command succeeds" (Right ()) result
  assertEqual "version output" ["bearilo " <> beariloVersion <> "\n"] output

testInitCli :: IO ()
testInitCli =
  assertCliCommand "init branch" CliInit ["--init"]

testListPresetsCli :: IO ()
testListPresetsCli =
  assertCliCommand "list presets branch" CliListPresets ["--list-presets"]

testListDevicesCli :: IO ()
testListDevicesCli =
  assertCliCommand "list devices branch" CliListDevices ["--list-devices"]

testHiddenNoSurprises :: IO ()
testHiddenNoSurprises =
  case parseCliPure ["--no-surprises"] of
    Right options -> assertEqual "hidden no-surprises parses" True (cliNoSurprises options)
    other -> error ("expected no-surprises parse success, got: " <> show other)

testStartupLogsStarting :: IO ()
testStartupLogsStarting = do
  (_, logs) <- runWithCaptured defaultCliOptions {cliPresets = ["default"]} readConfigFixture
  assertBool "startup logs Starting" (any ("INFO bearilo: Starting..." `isInfixOf`) logs)

testDefaultConfigLogsWarning :: IO ()
testDefaultConfigLogsWarning = do
  (_, logs) <-
    runWithCaptured defaultCliOptions {cliPresets = ["default"]} $ \logger _ -> do
      logWarn logger "Using the default configuration (run with `--init` to save it to a file)."
      pure (Right appConfigFixture)
  assertBool
    "default config fallback logs warning"
    (any ("WARN bearilo: Using the default configuration" `isInfixOf`) logs)

testNoPresetLogsWarning :: IO ()
testNoPresetLogsWarning = do
  (_, logs) <- runWithCaptured defaultCliOptions readConfigFixture
  assertBool
    "missing preset logs default preset warning"
    (any ("WARN bearilo: No preset specified, using the default preset." `isInfixOf`) logs)

testExplicitMissingConfigDoesNotLogFallback :: IO ()
testExplicitMissingConfigDoesNotLogFallback = do
  (_, logs) <-
    runWithCaptured defaultCliOptions {cliConfigPath = Just "missing.toml"} $ \_ _ ->
      pure (Left (AppConfigError (ConfigPathMissing "missing.toml")))
  assertBool
    "explicit missing config does not log default config fallback"
    (not (any ("Using the default configuration" `isInfixOf`) logs))

testNormalSoundPathPlaysDefaultSyntheticPress :: IO ()
testNormalSoundPathPlaysDefaultSyntheticPress = do
  choicesRef <- newIORef []
  result <-
    runWith
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions {cliVerbose = 2}),
          runtimeReadConfig = readConfigFixture,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \_ -> pure (),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ callback -> callback (KeyPressed "KeyA") >> pure (Right ()),
          runtimePlay = \_ choice -> modifyIORef' choicesRef (<> [choice]) >> pure (Right ()),
          runtimeUseColor = False
        }
  choices <- readIORef choicesRef
  assertEqual "synthetic run succeeds" (Right ()) result
  assertBool "default synthetic press selects a sound" (any hasSound choices)
  where
    hasSound choice =
      case choiceSound choice of
        Just sound -> soundPath sound == "keydown.mp3"
        Nothing -> False

testPlaybackErrorIsLogged :: IO ()
testPlaybackErrorIsLogged = do
  logsRef <- newIORef []
  result <-
    runWith
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions),
          runtimeReadConfig = readConfigFixture,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \line -> modifyIORef' logsRef (<> [line]),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ callback -> callback (KeyPressed "KeyA") >> pure (Right ()),
          runtimePlay = \_ _ -> pure (Left (AppAudioError (AudioPlayError "boom"))),
          runtimeUseColor = False
        }
  logs <- readIORef logsRef
  assertEqual "playback failure is logged but listener continues" (Right ()) result
  assertBool "playback failure log is visible" (any ("WARN bearilo: Playback failed: AudioPlayError \"boom\"" `isInfixOf`) logs)

testUserInterruptCleanShutdown :: IO ()
testUserInterruptCleanShutdown = do
  logsRef <- newIORef []
  result <-
    runWith
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions {cliPresets = ["default"], cliVerbose = 2}),
          runtimeReadConfig = readConfigFixture,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \line -> modifyIORef' logsRef (<> [line]),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \_ -> pure (Left (AppAudioError AudioInterrupted)),
          runtimeListen = \_ _ -> pure (Right ()),
          runtimePlay = \_ _ -> pure (Right ()),
          runtimeUseColor = False
        }
  logs <- readIORef logsRef
  assertEqual "user interrupt returns cleanly" (Right ()) result
  assertBool "user interrupt is not logged as audio backend failure" (not (any ("Audio backend failed" `isInfixOf`) logs))

testDaktiloStyleReturnDebugLogs :: IO ()
testDaktiloStyleReturnDebugLogs = do
  (_, logs) <- runDebugEvent (KeyPressed "Return")
  assertBool "debug logs Return event" (any ("DEBUG bearilo: Event: press Return" `isInfixOf`) logs)
  assertBool "debug logs Return key config" (any ("DEBUG bearilo: Key config: press Return -> ding.mp3" `isInfixOf`) logs)
  assertBool "debug logs Return playing file" (any ("DEBUG bearilo: Playing: ding.mp3" `isInfixOf`) logs)
  assertBool "debug logs identity Return params" (any ("DEBUG bearilo: Volume: 1, Tempo: 1" `isInfixOf`) logs)

testDaktiloStyleFallbackDebugLogs :: IO ()
testDaktiloStyleFallbackDebugLogs = do
  (_, logs) <- runDebugEvent (KeyPressed "KeyC")
  assertBool "debug logs fallback event" (any ("DEBUG bearilo: Event: press KeyC" `isInfixOf`) logs)
  assertBool "debug logs fallback key config" (any ("DEBUG bearilo: Key config: press .* -> keydown.mp3" `isInfixOf`) logs)
  assertBool "debug logs fallback playing file" (any ("DEBUG bearilo: Playing: keydown.mp3" `isInfixOf`) logs)
  assertBool "debug logs varied fallback params" (any variedParams logs)
  where
    variedParams logLine =
      "DEBUG bearilo: Volume: " `isInfixOf` logLine
        && "Tempo:" `isInfixOf` logLine
        && not ("Volume: 1, Tempo: 1" `isInfixOf` logLine)

testEnvPreset :: IO ()
testEnvPreset =
  assertEqual
    "PRESET maps to preset"
    ["basic"]
    (cliPresets (mergeCliEnv (cliEnvFromPairs [("PRESET", "basic")]) defaultCliOptions))

testEnvDevice :: IO ()
testEnvDevice =
  assertEqual
    "DAKTILO_DEVICE maps to device"
    (Just "Built-in")
    (cliDevice (mergeCliEnv (cliEnvFromPairs [("DAKTILO_DEVICE", "Built-in")]) defaultCliOptions))

testEnvConfig :: IO ()
testEnvConfig =
  assertEqual
    "DAKTILO_CONFIG maps to config path"
    (Just "custom.toml")
    (cliConfigPath (mergeCliEnv (cliEnvFromPairs [("DAKTILO_CONFIG", "custom.toml")]) defaultCliOptions))

testEnvVolume :: IO ()
testEnvVolume =
  assertEqual
    "DAKTILO_VOLUME maps to volume variation"
    (Just VariationRange {variationDown = 0.1, variationUp = 0.2})
    (cliVolumeVariation (mergeCliEnv (cliEnvFromPairs [("DAKTILO_VOLUME", "0.1,0.2")]) defaultCliOptions))

testEnvTempo :: IO ()
testEnvTempo =
  assertEqual
    "DAKTILO_TEMPO maps to tempo variation"
    (Just VariationRange {variationDown = 0.3, variationUp = 0.4})
    (cliTempoVariation (mergeCliEnv (cliEnvFromPairs [("DAKTILO_TEMPO", "0.3 0.4")]) defaultCliOptions))

testDefaultPresetSelection :: IO ()
testDefaultPresetSelection =
  assertEqual
    "default preset selection uses default"
    (Right [defaultPreset])
    (selectPresets appConfigFixture [])

testMissingPreset :: IO ()
testMissingPreset =
  assertEqual
    "missing preset gives explicit error"
    (Left (PresetNotFound "missing"))
    (selectPresets appConfigFixture ["missing"])

testListPresetsColumns :: IO ()
testListPresetsColumns = do
  let output = listPresets appConfigFixture

  assertBool "list presets contains Event column" ("Event" `isInfixOf` output)
  assertBool "list presets contains Keys column" ("Keys" `isInfixOf` output)
  assertBool "list presets contains File column" ("File" `isInfixOf` output)

testPresetTablePadding :: IO ()
testPresetTablePadding = do
  let output = renderPresetList False [defaultPreset]
      outputLines = lines output
      header = outputLines !! 1
      separator = outputLines !! 2
      firstRow = outputLines !! 3

  assertEqual
    "plain preset table header spacing"
    "Event          Keys      File       "
    header
  assertEqual
    "plain preset separator spacing"
    "-----          ----      ----       "
    separator
  assertBool "preset table rows use padded columns" ("Key Press      Return" `isInfixOf` firstRow)

testPresetTableColor :: IO ()
testPresetTableColor = do
  let plain = renderPresetList False [defaultPreset]
      colored = renderPresetList True [defaultPreset]

  assertBool "plain preset table has no color" (not ("\ESC[" `isInfixOf` plain))
  assertBool "colored preset table colors headers" (colorHeader True "Event          Keys      File       " `isInfixOf` colored)

testEmbeddedPresetSections :: IO ()
testEmbeddedPresetSections =
  case parseConfig defaultConfigText of
    Left err -> error ("expected embedded config to parse: " <> show err)
    Right config -> do
      let output = renderPresetList False (configSoundPresets config)

      forM_
        ["[default]", "[basic]", "[musicbox]", "[ducktilo]", "[drumkit]", "[sparks]", "[vpaul]"]
        $ \section ->
          assertBool ("preset list contains " <> section) (section `isInfixOf` output)
      assertBool "file lists are comma-separated" ("dspark1.mp3,dspark2.mp3,dspark3.mp3" `isInfixOf` output)
      assertBool "plain embedded preset list has no color" (not ("\ESC[" `isInfixOf` output))

testDeviceListRendering :: IO ()
testDeviceListRendering = do
  let devices =
        [ OutputDevice (OutputDeviceName "MacBook Pro Speakers"),
          OutputDevice (OutputDeviceName "ZoomAudioDevice")
        ]
      plain = renderDeviceList False devices
      colored = renderDeviceList True devices

  assertBool "device list uses bullets" ("• MacBook Pro Speakers" `isInfixOf` plain)
  assertBool "plain device list has no color" (not ("\ESC[" `isInfixOf` plain))
  assertBool
    "device names are bright bold in color mode"
    (colorDeviceName True "MacBook Pro Speakers" `isInfixOf` colored)

testListPresetsSparks :: IO ()
testListPresetsSparks =
  assertBool "list presets contains sparks" ("sparks" `isInfixOf` listPresets appConfigFixture)

testListPresetsVpaul :: IO ()
testListPresetsVpaul =
  case parseConfig defaultConfigText of
    Left err -> error ("expected embedded config to parse: " <> show err)
    Right config ->
      assertBool "list presets contains vpaul" ("vpaul" `isInfixOf` listPresets config)

testListPresetsNoStandaloneSpark :: IO ()
testListPresetsNoStandaloneSpark =
  assertBool
    "list presets does not contain standalone spark"
    ("spark" `notElem` words (listPresets appConfigFixture))

testDisabledKeyNoSound :: IO ()
testDisabledKeyNoSound =
  assertEqual
    "disabled key returns no sound"
    []
    (soundChoicesForEvent (appConfig [disabledPreset]) (KeyPressed "KeyA"))

testDisabledKeyReleaseNoSound :: IO ()
testDisabledKeyReleaseNoSound =
  assertEqual
    "disabled key release returns no sound"
    []
    (soundChoicesForEvent (appConfig [disabledPreset]) (KeyReleased "KeyA"))

testDefaultReturnPressSelectsDing :: IO ()
testDefaultReturnPressSelectsDing =
  assertEqual
    "Return press in default preset selects ding"
    [Just "ding.mp3"]
    (map (fmap soundPath . choiceSound) (soundChoicesForEvent (appConfig [defaultPreset]) (KeyPressed "Return")))

testDefaultReturnReleaseIsSilent :: IO ()
testDefaultReturnReleaseIsSilent =
  assertEqual
    "Return release in default preset is silent"
    []
    (map (fmap soundPath . choiceSound) (soundChoicesForEvent (appConfig [defaultPreset]) (KeyReleased "Return")))

testDefaultNormalKeyReleaseSelectsKeyup :: IO ()
testDefaultNormalKeyReleaseSelectsKeyup =
  assertEqual
    "normal key release in default preset selects keyup"
    [Just "keyup.mp3"]
    (map (fmap soundPath . choiceSound) (soundChoicesForEvent (appConfig [defaultPreset]) (KeyReleased "KeyA")))

testFirstMatchingKeyConfigWins :: IO ()
testFirstMatchingKeyConfigWins =
  assertEqual
    "first matching key config wins"
    [Just firstSound]
    (map choiceSound (soundChoicesForEvent (appConfig [firstMatchPreset]) (KeyPressed "KeyA")))

testReleasePlaybackSelected :: IO ()
testReleasePlaybackSelected =
  assertEqual
    "release playback is selected"
    [Just releaseSound]
    (map choiceSound (soundChoicesForEvent (appConfig [pressReleasePreset]) (KeyReleased "KeyA")))

testRegexKeyMatch :: IO ()
testRegexKeyMatch =
  assertEqual
    "regex key match selects sound"
    [Just firstSound]
    (map choiceSound (soundChoicesForEvent (appConfig [regexPreset]) (KeyPressed "KeyA")))

testMultiplePresetChoices :: IO ()
testMultiplePresetChoices =
  assertEqual
    "multiple presets produce multiple choices"
    [Just firstSound, Just secondSound]
    (map choiceSound (soundChoicesForEvent (appConfig [firstPreset, secondPreset]) (KeyPressed "KeyA")))

testSequentialCycles :: IO ()
testSequentialCycles = do
  let (first, index1) = chooseSequential (SequentialIndex 0) (firstSound :| [secondSound])
      (second, _) = chooseSequential index1 (firstSound :| [secondSound])

  assertEqual "sequential first" firstSound first
  assertEqual "sequential second" secondSound second

testRandomReturnsConfiguredSound :: IO ()
testRandomReturnsConfiguredSound = do
  let (sound, _) = chooseRandom (RandomSeed 7) (firstSound :| [secondSound])

  assertBool "random returns configured sound" (sound `elem` [firstSound, secondSound])

testAk47HiddenPreset :: IO ()
testAk47HiddenPreset =
  case resolveHiddenPreset True "ak47" of
    Just preset ->
      assertEqual
        "ak47 hidden preset files"
        ["mbox10.mp3", "mbox11.mp3", "mbox9.mp3"]
        [audioFilePath file | keyConfig <- presetKeyConfigs preset, file <- keyConfigFiles keyConfig]
    Nothing ->
      error "expected ak47 hidden preset"

testNoSurprisesDisablesRandomHiddenPreset :: IO ()
testNoSurprisesDisablesRandomHiddenPreset =
  assertEqual
    "no_surprises disables random hidden surprise path"
    Nothing
    (resolveHiddenPreset True "__random_surprise__")

assertCliCommand :: String -> CliCommand -> [String] -> IO ()
assertCliCommand label expected args =
  case parseCliPure args of
    Right options -> assertEqual label expected (cliCommand options)
    other -> error ("expected CLI parse success, got: " <> show other)

assertCliVerbose :: String -> Int -> [String] -> IO ()
assertCliVerbose label expected args =
  case parseCliPure args of
    Right options -> assertEqual label expected (cliVerbose options)
    other -> error ("expected CLI parse success, got: " <> show other)

runWithCaptured ::
  CliOptions ->
  (Logger -> CliOptions -> IO (Either AppError Config)) ->
  IO (Either AppError (), [String])
runWithCaptured options readConfig = do
  logsRef <- newIORef []
  result <- runWith (runtime logsRef)
  logs <- readIORef logsRef
  pure (result, logs)
  where
    runtime logsRef =
      Runtime
        { runtimeParseCli = pure (Right options),
          runtimeReadConfig = readConfig,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \line -> modifyIORef' logsRef (<> [line]),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ _ -> pure (Right ()),
          runtimePlay = \_ _ -> pure (Right ()),
          runtimeUseColor = False
        }

runDebugEvent :: KeyEvent -> IO (Either AppError (), [String])
runDebugEvent event = do
  logsRef <- newIORef []
  result <- runWith (runtime logsRef)
  logs <- readIORef logsRef
  pure (result, logs)
  where
    runtime logsRef =
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions {cliPresets = ["default"], cliVerbose = 2}),
          runtimeReadConfig = readConfigFixture,
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \line -> modifyIORef' logsRef (<> [line]),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ callback -> callback event >> pure (Right ()),
          runtimePlay = \_ _ -> pure (Right ()),
          runtimeUseColor = False
        }

readConfigFixture :: Logger -> CliOptions -> IO (Either AppError Config)
readConfigFixture _ _ =
  pure (Right appConfigFixture)

fixedTime :: UTCTime
fixedTime =
  read "2026-04-28 09:06:28.980578 UTC"

testEngine :: AudioEngine
testEngine =
  AudioEngine
    { audioEnginePlaybackSlots = defaultPlaybackSlots
    }

appConfigFixture :: Config
appConfigFixture =
  Config
    { configNoSurprises = False,
      configSoundPresets =
        [ defaultPreset,
          sparksPreset
        ]
    }

defaultPreset :: SoundPreset
defaultPreset =
  SoundPreset
    { presetName = "default",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs =
        [ pressConfig "Return" [audioFile "ding.mp3"],
          (pressConfig ".*" [audioFile "keydown.mp3"]) {keyConfigVariation = Just defaultVariation},
          (releaseConfig ".*" [audioFile "keyup.mp3"]) {keyConfigVariation = Just defaultVariation}
        ]
    }

sparksPreset :: SoundPreset
sparksPreset =
  SoundPreset
    { presetName = "sparks",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs = [pressConfig ".*" [audioFile "dspark1.mp3"]]
    }

disabledPreset :: SoundPreset
disabledPreset =
  defaultPreset {presetDisabledKeys = ["KeyA"]}

firstMatchPreset :: SoundPreset
firstMatchPreset =
  SoundPreset
    { presetName = "first-match",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs =
        [ pressConfig ".*" [audioFile "first.mp3"],
          pressConfig ".*" [audioFile "second.mp3"]
        ]
    }

pressReleasePreset :: SoundPreset
pressReleasePreset =
  SoundPreset
    { presetName = "press-release",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs =
        [ pressConfig "KeyA" [audioFile "press.mp3"],
          releaseConfig "KeyA" [audioFile "release.mp3"]
        ]
    }

regexPreset :: SoundPreset
regexPreset =
  SoundPreset
    { presetName = "regex",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs = [pressConfig "Key.*" [audioFile "first.mp3"]]
    }

firstPreset :: SoundPreset
firstPreset =
  SoundPreset
    { presetName = "first",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs = [pressConfig "KeyA" [audioFile "first.mp3"]]
    }

secondPreset :: SoundPreset
secondPreset =
  SoundPreset
    { presetName = "second",
      presetDisabledKeys = [],
      presetVariation = Nothing,
      presetKeyConfigs = [pressConfig "KeyA" [audioFile "second.mp3"]]
    }

appConfig :: [SoundPreset] -> AppConfig
appConfig presets =
  AppConfig
    { appPresets = presets,
      appDevice = Nothing,
      appNoSurprises = False,
      appVolumeVariation = Nothing,
      appTempoVariation = Nothing
    }

pressConfig :: Text -> [AudioFile] -> KeyConfig
pressConfig keyPattern files =
  KeyConfig
    { keyConfigEvent = KeyPress,
      keyConfigKeys = keyPattern,
      keyConfigFiles = files,
      keyConfigStrategy = Nothing,
      keyConfigVariation = Nothing
    }

releaseConfig :: Text -> [AudioFile] -> KeyConfig
releaseConfig keyPattern files =
  KeyConfig
    { keyConfigEvent = KeyRelease,
      keyConfigKeys = keyPattern,
      keyConfigFiles = files,
      keyConfigStrategy = Nothing,
      keyConfigVariation = Nothing
    }

defaultVariation :: SoundVariation
defaultVariation =
  SoundVariation
    { soundVariationVolume = Just VariationRange {variationDown = 0.1, variationUp = 0.1},
      soundVariationTempo = Just VariationRange {variationDown = 0.05, variationUp = 0.05}
    }

audioFile :: FilePath -> AudioFile
audioFile path =
  AudioFile
    { audioFilePath = path,
      audioFileVolume = Nothing
    }

firstSound :: Sound
firstSound =
  Sound
    { soundPath = "first.mp3",
      soundBytes = Nothing,
      soundVolume = 1.0
    }

secondSound :: Sound
secondSound =
  Sound
    { soundPath = "second.mp3",
      soundBytes = Nothing,
      soundVolume = 1.0
    }

releaseSound :: Sound
releaseSound =
  Sound
    { soundPath = "release.mp3",
      soundBytes = Nothing,
      soundVolume = 1.0
    }

assertBool :: String -> Bool -> IO ()
assertBool _ True = pure ()
assertBool message False = error message

countOccurrences :: String -> String -> Int
countOccurrences needle haystack
  | null needle = 0
  | otherwise = go haystack
  where
    go [] = 0
    go text
      | needle `isPrefixOf` text = 1 + go (drop (length needle) text)
      | otherwise = go (drop 1 text)

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
