module AppSpec (spec) where

import Bearilo.App
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Cli
import Bearilo.Error
import Bearilo.Types
import Data.List (isInfixOf)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)

spec :: IO ()
spec = do
  testHelpPath
  testInitCli
  testListPresetsCli
  testListDevicesCli
  testHiddenNoSurprises
  testEnvPreset
  testEnvDevice
  testEnvConfig
  testEnvVolume
  testEnvTempo
  testDefaultPresetSelection
  testMissingPreset
  testListPresetsColumns
  testListPresetsSparks
  testListPresetsNoStandaloneSpark
  testDisabledKeyNoSound
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
      assertBool "hidden no-surprises is absent from help" (not ("--no-surprises" `isInfixOf` helpText))
    other -> error ("expected help parser path, got: " <> show other)

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
    (Left (AppConfigError (PresetNotFound "missing")))
    (selectPresets appConfigFixture ["missing"])

testListPresetsColumns :: IO ()
testListPresetsColumns = do
  let output = listPresets appConfigFixture

  assertBool "list presets contains Event column" ("Event" `isInfixOf` output)
  assertBool "list presets contains Keys column" ("Keys" `isInfixOf` output)
  assertBool "list presets contains File column" ("File" `isInfixOf` output)

testListPresetsSparks :: IO ()
testListPresetsSparks =
  assertBool "list presets contains sparks" ("sparks" `isInfixOf` listPresets appConfigFixture)

testListPresetsNoStandaloneSpark :: IO ()
testListPresetsNoStandaloneSpark =
  assertBool
    "list presets does not contain standalone spark"
    (not (any (== "spark") (words (listPresets appConfigFixture))))

testDisabledKeyNoSound :: IO ()
testDisabledKeyNoSound =
  assertEqual
    "disabled key returns no sound"
    []
    (soundChoicesForEvent (appConfig [disabledPreset]) (KeyPressed "KeyA"))

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
      presetKeyConfigs = [pressConfig ".*" [audioFile "keydown.mp3"]]
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

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
