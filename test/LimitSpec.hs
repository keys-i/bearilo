module LimitSpec (spec) where

import Bearilo.App
import Bearilo.Assets
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Cli
import Bearilo.Config
import Bearilo.Error
import Bearilo.Os.Types
import Bearilo.Types
import Control.Exception (SomeException, try)
import Data.Foldable (toList)
import Data.List (isInfixOf, nub)
import Data.List.NonEmpty (NonEmpty (..))
import System.FilePath (takeFileName)

spec :: IO ()
spec = do
  testMainOnlyCallsAppRun
  testExplicitMissingConfigPath
  testInputHasNoFfi
  testInputDoesNotImportAudio
  testAppDoesNotOwnSoundMatching
  testRandomChoiceDeterministic
  testVariationApplicationPure
  testSequentialStatePerKeyConfig
  testDeviceLookupCaseInsensitive
  testListenerStartupFailureReturnsLeft
  testEmbeddedConfigSoundsPresent
  testAudioTestsUseCurrentApi
  testPresetListContainsSparks
  testPresetListNoStandaloneSpark

testMainOnlyCallsAppRun :: IO ()
testMainOnlyCallsAppRun = do
  contents <- readFile "app/Main.hs"
  assertEqual
    "app/Main.hs only calls App.run"
    [ "module Main (main) where",
      "import qualified Bearilo.App as App",
      "main :: IO ()",
      "main = App.run"
    ]
    (filter (not . null) (lines contents))

testExplicitMissingConfigPath :: IO ()
testExplicitMissingConfigPath = do
  let path = "definitely-missing-bearilo-v070.toml"
  result <- resolveConfigPath (Just path)
  assertEqual
    "explicit missing config path returns ConfigPathMissing"
    (Left (ConfigPathMissing path))
    result

testInputHasNoFfi :: IO ()
testInputHasNoFfi = do
  contents <- readFile "src/Bearilo/Input.hs"
  assertBool "Bearilo.Input does not import FFI" (not ("foreign import" `isInfixOf` contents))

testInputDoesNotImportAudio :: IO ()
testInputDoesNotImportAudio = do
  contents <- readFile "src/Bearilo/Input.hs"
  assertBool "Bearilo.Input does not import Bearilo.Audio" (not ("Bearilo.Audio" `isInfixOf` contents))

testAppDoesNotOwnSoundMatching :: IO ()
testAppDoesNotOwnSoundMatching = do
  contents <- readFile "src/Bearilo/App.hs"
  assertBool "Bearilo.App leaves regex matching to pure audio code" (not ("Text.Regex.TDFA" `isInfixOf` contents))

testRandomChoiceDeterministic :: IO ()
testRandomChoiceDeterministic =
  assertEqual
    "random choice is deterministic for same seed"
    (chooseRandom (RandomSeed 42) sounds)
    (chooseRandom (RandomSeed 42) sounds)

testVariationApplicationPure :: IO ()
testVariationApplicationPure =
  assertEqual
    "variation application is pure for same inputs"
    (applyVariation VariationUp variation 1.0)
    (applyVariation VariationUp variation 1.0)
  where
    variation =
      SoundVariation
        { soundVariationVolume = Just VariationRange {variationDown = 0.1, variationUp = 0.2},
          soundVariationTempo = Nothing
        }

testSequentialStatePerKeyConfig :: IO ()
testSequentialStatePerKeyConfig = do
  let (firstA, stateAfterA) = nextSequentialFor (KeyConfigId "A") emptySequentialState sounds
      (firstB, _) = nextSequentialFor (KeyConfigId "B") stateAfterA sounds
      (secondA, _) = nextSequentialFor (KeyConfigId "A") stateAfterA sounds

  assertEqual "first A selection" firstSound firstA
  assertEqual "A does not advance B" firstSound firstB
  assertEqual "A advances independently" secondSound secondA

testDeviceLookupCaseInsensitive :: IO ()
testDeviceLookupCaseInsensitive =
  assertEqual
    "device lookup matches requested and available names case-insensitively"
    (Right device)
    (findOutputDevice "built in output" [device])
  where
    device =
      OutputDevice
        { outputDeviceName = OutputDeviceName "Built In Output"
        }

testListenerStartupFailureReturnsLeft :: IO ()
testListenerStartupFailureReturnsLeft = do
  result <- try (runCommand runtime defaultCliOptions) :: IO (Either SomeException (Either AppError ()))
  case result of
    Left err -> error ("listener startup failure threw exception: " <> show err)
    Right actual ->
      assertEqual
        "listener startup failure returns Left"
        (Left (AppOsHookError (OsUnsupportedPlatform "test listener failure")))
        actual
  where
    runtime =
      Runtime
        { runtimeParseCli = pure (Right defaultCliOptions),
          runtimeReadConfig = \_ _ -> pure (Right configFixture),
          runtimeWriteFile = \_ _ -> pure (),
          runtimeOutput = \_ -> pure (),
          runtimeLogOutput = \_ -> pure (),
          runtimeCurrentTime = pure fixedTime,
          runtimeListDevices = pure (Right []),
          runtimeWithAudio = \action -> action testEngine,
          runtimeListen = \_ _ -> pure (Left (AppOsHookError (OsUnsupportedPlatform "test listener failure"))),
          runtimePlay = \_ _ -> pure (Right ()),
          runtimeUseColor = False
        }
    fixedTime = read "2026-04-28 09:06:28.980578 UTC"
    testEngine =
      AudioEngine
        { audioEnginePlaybackSlots = defaultPlaybackSlots
        }

testEmbeddedConfigSoundsPresent :: IO ()
testEmbeddedConfigSoundsPresent =
  case parseConfig defaultConfigText of
    Left err -> error ("expected embedded config to parse: " <> show err)
    Right config -> do
      let manifest = toList assetManifest
          referenced = nub (map takeFileName (allReferencedSoundPaths config))
          missing = filter (`notElem` manifest) referenced

      assertEqual "embedded config sound paths are all present in asset manifest" [] missing

testAudioTestsUseCurrentApi :: IO ()
testAudioTestsUseCurrentApi = do
  contents <- readFile "test/AudioSpec.hs"
  assertBool "audio tests do not mention stale App::init API" (not ("App::init" `isInfixOf` contents))
  assertBool "audio tests target current SoundChoice API" ("SoundChoice" `isInfixOf` contents)

testPresetListContainsSparks :: IO ()
testPresetListContainsSparks =
  assertBool "preset list contains sparks" ("sparks" `isInfixOf` listPresets configFixture)

testPresetListNoStandaloneSpark :: IO ()
testPresetListNoStandaloneSpark =
  assertBool
    "preset list does not contain standalone spark"
    ("spark" `notElem` words (listPresets configFixture))

allReferencedSoundPaths :: Config -> [FilePath]
allReferencedSoundPaths config =
  [ audioFilePath file
    | preset <- configSoundPresets config,
      keyConfig <- presetKeyConfigs preset,
      file <- keyConfigFiles keyConfig
  ]

configFixture :: Config
configFixture =
  Config
    { configNoSurprises = False,
      configSoundPresets =
        [ SoundPreset
            { presetName = "default",
              presetDisabledKeys = [],
              presetVariation = Nothing,
              presetKeyConfigs = [pressConfig ".*" [audioFile "keydown.mp3"]]
            },
          SoundPreset
            { presetName = "sparks",
              presetDisabledKeys = [],
              presetVariation = Nothing,
              presetKeyConfigs = [pressConfig ".*" [audioFile "dspark1.mp3"]]
            }
        ]
    }

pressConfig :: PresetName -> [AudioFile] -> KeyConfig
pressConfig keyPattern files =
  KeyConfig
    { keyConfigEvent = KeyPress,
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

sounds :: NonEmpty Sound
sounds =
  firstSound :| [secondSound]

assertBool :: String -> Bool -> IO ()
assertBool _ True = pure ()
assertBool message False = error message

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
