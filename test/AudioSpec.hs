module AudioSpec (spec) where

import Bearilo.Assets (lookupEmbeddedSound)
import Bearilo.Audio
import Bearilo.Audio.Types
import Bearilo.Types
  ( AppConfig (..),
    AudioFile (..),
    KeyConfig (..),
    KeyEvent (..),
    SoundPreset (..),
    SoundVariation (..),
    VariationRange (..),
  )
import Control.Monad (when)
import Data.ByteString.Char8 qualified as ByteString
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory
  ( createDirectoryIfMissing,
    doesFileExist,
    getTemporaryDirectory,
    removeFile,
  )
import System.FilePath ((</>))

spec :: IO ()
spec = do
  testMissingStrategySelectsFirst
  testSequentialCycles
  testRandomResultComesFromInput
  testSoundForEventDisabledKey
  testSoundForEventFirstMatchWins
  testSoundForEventPress
  testSoundForEventRelease
  testVariationPrecedence
  testVariationDefaultsToIdentity
  testVolumeDefault
  testConfiguredVolumeMultipliesPlaybackVolume
  testIdentityTempoAllowed
  testNonIdentityTempoAllowed
  testResampleIdentityReturnsUnchangedSamples
  testResampleFasterTempoShortensSamples
  testResampleSlowerTempoLengthensSamples
  testResampleZeroTempoReturnsExplicitError
  testResampleNegativeTempoReturnsExplicitError
  testSourceIndexForRateStaysInBounds
  testEmbeddedSourcePreferredOverFilePathSource
  testMissingEmbeddedSourceFallsBackToFilePathSource
  testMissingFileReturnsExplicitError
  testDefaultPlaybackSlots
  testSoundSelectionRequiresNonEmpty

testMissingStrategySelectsFirst :: IO ()
testMissingStrategySelectsFirst =
  assertEqual
    "missing strategy selects first sound"
    firstSound
    (chooseFirst sounds)

testSequentialCycles :: IO ()
testSequentialCycles = do
  let (first, index1) = chooseSequential (SequentialIndex 0) sounds
      (second, index2) = chooseSequential index1 sounds
      (third, index3) = chooseSequential index2 sounds
      (againFirst, _) = chooseSequential index3 sounds

  assertEqual "sequential first" firstSound first
  assertEqual "sequential second" secondSound second
  assertEqual "sequential third" thirdSound third
  assertEqual "sequential cycles" firstSound againFirst

testRandomResultComesFromInput :: IO ()
testRandomResultComesFromInput = do
  let (sound, _) = chooseRandom (RandomSeed 42) sounds

  if sound `elem` NonEmpty.toList sounds
    then pure ()
    else error "random result is from input"

testSoundForEventDisabledKey :: IO ()
testSoundForEventDisabledKey =
  assertEqual
    "disabled key produces no sound"
    Nothing
    (choiceSound (soundForEvent appConfig {appPresets = [disabledPreset]} (KeyPressed (txt "a"))))

testSoundForEventFirstMatchWins :: IO ()
testSoundForEventFirstMatchWins =
  assertEqual
    "first matching key config wins"
    (Just firstSound)
    (choiceSound (soundForEvent appConfig {appPresets = [firstMatchPreset]} (KeyPressed (txt "a"))))

testSoundForEventPress :: IO ()
testSoundForEventPress =
  assertEqual
    "press event uses press config"
    (Just firstSound)
    (choiceSound (soundForEvent appConfig {appPresets = [pressReleasePreset]} (KeyPressed (txt "a"))))

testSoundForEventRelease :: IO ()
testSoundForEventRelease =
  assertEqual
    "release event uses release config"
    (Just secondSound)
    (choiceSound (soundForEvent appConfig {appPresets = [pressReleasePreset]} (KeyReleased (txt "a"))))

testVariationPrecedence :: IO ()
testVariationPrecedence = do
  assertEqual
    "CLI variation wins"
    cliVariation
    (choiceVariation (soundForEvent cliVariationConfig (KeyPressed (txt "a"))))

  assertEqual
    "key variation wins when CLI variation is absent"
    keyVariation
    (resolveVariation Nothing (Just keyVariation) (Just presetLevelVariation))

  assertEqual
    "preset variation is used when CLI and key variations are absent"
    presetLevelVariation
    (resolveVariation Nothing Nothing (Just presetLevelVariation))
  where
    cliVariationConfig =
      appConfig
        { appVolumeVariation = soundVariationVolume cliVariation,
          appTempoVariation = soundVariationTempo cliVariation,
          appPresets = [variationPreset]
        }

testVariationDefaultsToIdentity :: IO ()
testVariationDefaultsToIdentity = do
  let variation = resolveVariation Nothing Nothing Nothing

  assertEqual
    "missing variation keeps value unchanged"
    10.0
    (applyVariation VariationUp variation 10.0)

testVolumeDefault :: IO ()
testVolumeDefault =
  assertEqual
    "volume defaults to 1.0"
    (Just 1.0)
    (soundVolume <$> choiceSound (loadSoundChoice source))
  where
    source =
      SoundSource
        { sourcePath = "default-volume.mp3",
          sourceBytes = Nothing,
          sourceVolume = Nothing
        }

testConfiguredVolumeMultipliesPlaybackVolume :: IO ()
testConfiguredVolumeMultipliesPlaybackVolume =
  assertEqual
    "configured volume multiplies playback volume"
    0.4
    (applyConfiguredVolume 0.8 0.5)

testIdentityTempoAllowed :: IO ()
testIdentityTempoAllowed =
  assertEqual
    "identity tempo is allowed"
    (Right ())
    (validatePlaybackParams defaultPlaybackParams)

testNonIdentityTempoAllowed :: IO ()
testNonIdentityTempoAllowed =
  assertEqual
    "non-identity tempo is allowed"
    (Right ())
    (validatePlaybackParams defaultPlaybackParams {playbackTempo = 1.25})

testResampleIdentityReturnsUnchangedSamples :: IO ()
testResampleIdentityReturnsUnchangedSamples =
  assertEqual
    "identity tempo returns unchanged samples"
    (Right [1 :: Int, 2, 3, 4])
    (resampleNearest 1.0 [1 :: Int, 2, 3, 4])

testResampleFasterTempoShortensSamples :: IO ()
testResampleFasterTempoShortensSamples =
  assertEqual
    "tempo factor 2.0 makes output shorter"
    (Right 2)
    (resampledLength 2.0 4)

testResampleSlowerTempoLengthensSamples :: IO ()
testResampleSlowerTempoLengthensSamples =
  assertEqual
    "tempo factor 0.5 makes output longer"
    (Right 8)
    (resampledLength 0.5 4)

testResampleZeroTempoReturnsExplicitError :: IO ()
testResampleZeroTempoReturnsExplicitError =
  assertEqual
    "zero tempo returns explicit error"
    (Left (InvalidTempoFactor 0.0))
    (resampleNearest 0.0 [1 :: Int, 2, 3])

testResampleNegativeTempoReturnsExplicitError :: IO ()
testResampleNegativeTempoReturnsExplicitError =
  assertEqual
    "negative tempo returns explicit error"
    (Left (InvalidTempoFactor (-1.0)))
    (resampleNearest (-1.0) [1 :: Int, 2, 3])

testSourceIndexForRateStaysInBounds :: IO ()
testSourceIndexForRateStaysInBounds =
  case resampledLength tempo inputLength of
    Left err ->
      error ("expected resampled length, got: " <> show err)
    Right outputLength ->
      if all indexInBounds [0 .. outputLength - 1]
        then pure ()
        else error "source index went out of bounds"
  where
    tempo = 1.75
    inputLength = 17

    indexInBounds outputIndex =
      let sourceIndex = sourceIndexForRate tempo outputIndex
       in sourceIndex >= 0 && sourceIndex < inputLength

testEmbeddedSourcePreferredOverFilePathSource :: IO ()
testEmbeddedSourcePreferredOverFilePathSource = do
  path <- audioSpecPath "ding.mp3"
  ByteString.writeFile path (ByteString.pack "file bytes")

  result <-
    loadSound
      testEngine
      SoundSource
        { sourcePath = path,
          sourceBytes = Nothing,
          sourceVolume = Nothing
        }

  case (result, lookupEmbeddedSound "ding.mp3") of
    (Right loadedSound, Just embeddedBytes) ->
      assertEqual
        "embedded source is preferred over file path source"
        embeddedBytes
        (loadedSoundBytes loadedSound)
    (Right _, Nothing) ->
      error "expected embedded ding.mp3"
    (Left err, _) ->
      error ("expected embedded sound, got: " <> show err)

testMissingEmbeddedSourceFallsBackToFilePathSource :: IO ()
testMissingEmbeddedSourceFallsBackToFilePathSource = do
  path <- audioSpecPath "not-embedded-bearilo-audio-spec.mp3"
  let fileBytes = ByteString.pack "file fallback bytes"
  ByteString.writeFile path fileBytes

  result <-
    loadSound
      testEngine
      SoundSource
        { sourcePath = path,
          sourceBytes = Nothing,
          sourceVolume = Nothing
        }

  case result of
    Right loadedSound ->
      assertEqual
        "missing embedded source falls back to file path source"
        fileBytes
        (loadedSoundBytes loadedSound)
    Left err ->
      error ("expected file fallback sound, got: " <> show err)

testMissingFileReturnsExplicitError :: IO ()
testMissingFileReturnsExplicitError = do
  path <- audioSpecPath "missing-bearilo-audio-spec.mp3"
  exists <- doesFileExist path
  when exists (removeFile path)

  result <-
    loadSound
      testEngine
      SoundSource
        { sourcePath = path,
          sourceBytes = Nothing,
          sourceVolume = Nothing
        }

  assertEqual
    "missing file returns explicit error"
    (Left (AudioMissingFile path))
    result

testDefaultPlaybackSlots :: IO ()
testDefaultPlaybackSlots =
  assertEqual
    "default playback slots"
    8
    defaultPlaybackSlots

testSoundSelectionRequiresNonEmpty :: IO ()
testSoundSelectionRequiresNonEmpty =
  assertEqual
    "sound selection takes NonEmpty input"
    firstSound
    (chooseFirst oneSound)
  where
    oneSound :: NonEmpty Sound
    oneSound = firstSound :| []

testEngine :: AudioEngine
testEngine =
  AudioEngine
    { audioEnginePlaybackSlots = defaultPlaybackSlots
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

thirdSound :: Sound
thirdSound =
  Sound
    { soundPath = "third.mp3",
      soundBytes = Nothing,
      soundVolume = 1.0
    }

sounds :: NonEmpty Sound
sounds =
  firstSound :| [secondSound, thirdSound]

appConfig :: AppConfig
appConfig =
  AppConfig
    { appPresets = [firstMatchPreset],
      appDevice = Nothing,
      appNoSurprises = False,
      appVolumeVariation = Nothing,
      appTempoVariation = Nothing
    }

disabledPreset :: SoundPreset
disabledPreset =
  firstMatchPreset
    { presetDisabledKeys = [txt "a"]
    }

firstMatchPreset :: SoundPreset
firstMatchPreset =
  SoundPreset
    { presetName = txt "first-match",
      presetKeyConfigs =
        [ pressConfig (txt ".*") [audioFile "first.mp3"],
          pressConfig (txt ".*") [audioFile "second.mp3"]
        ],
      presetDisabledKeys = [],
      presetVariation = Nothing
    }

pressReleasePreset :: SoundPreset
pressReleasePreset =
  SoundPreset
    { presetName = txt "press-release",
      presetKeyConfigs =
        [ pressConfig (txt "a") [audioFile "first.mp3"],
          releaseConfig (txt "a") [audioFile "second.mp3"]
        ],
      presetDisabledKeys = [],
      presetVariation = Nothing
    }

variationPreset :: SoundPreset
variationPreset =
  SoundPreset
    { presetName = txt "variation",
      presetKeyConfigs =
        [ (pressConfig (txt "a") [audioFile "first.mp3"])
            { keyConfigVariation = Just keyVariation
            }
        ],
      presetDisabledKeys = [],
      presetVariation = Just presetLevelVariation
    }

pressConfig :: Text -> [AudioFile] -> KeyConfig
pressConfig keys files =
  KeyConfig
    { keyConfigEvent = KeyPress,
      keyConfigKeys = keys,
      keyConfigFiles = files,
      keyConfigStrategy = Nothing,
      keyConfigVariation = Nothing
    }

releaseConfig :: Text -> [AudioFile] -> KeyConfig
releaseConfig keys files =
  KeyConfig
    { keyConfigEvent = KeyRelease,
      keyConfigKeys = keys,
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

audioSpecPath :: FilePath -> IO FilePath
audioSpecPath fileName = do
  tempDirectory <- getTemporaryDirectory
  let directory = tempDirectory </> "bearilo-audio-spec"
  createDirectoryIfMissing True directory
  pure (directory </> fileName)

cliVariation :: SoundVariation
cliVariation =
  volumeVariation 0.3 0.4

keyVariation :: SoundVariation
keyVariation =
  volumeVariation 0.2 0.2

presetLevelVariation :: SoundVariation
presetLevelVariation =
  volumeVariation 0.1 0.1

volumeVariation :: Double -> Double -> SoundVariation
volumeVariation down up =
  SoundVariation
    { soundVariationVolume =
        Just
          VariationRange
            { variationDown = down,
              variationUp = up
            },
      soundVariationTempo = Nothing
    }

txt :: String -> Text
txt =
  Text.pack

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
