module Bearilo.Audio
  ( applyConfiguredVolume,
    applyVariation,
    chooseFirst,
    chooseRandom,
    chooseSequential,
    defaultVolume,
    findOutputDevice,
    listOutputDevices,
    loadSound,
    loadSoundChoice,
    nextSequentialFor,
    playSound,
    resampleNearest,
    resampledLength,
    resolveVariation,
    soundForEvent,
    soundsForKeyConfig,
    sourceIndexForRate,
    withAudio,
  )
where

import Bearilo.Assets (lookupEmbeddedSound)
import Bearilo.Audio.SDL qualified as SDL
import Bearilo.Audio.Types
import Bearilo.Types
  ( AppConfig (..),
    AudioFile (..),
    KeyConfig (..),
    KeyEvent (..),
    PlaybackStrategy (..),
    SoundPreset (..),
    SoundVariation (..),
    VariationRange (..),
  )
import Control.Applicative ((<|>))
import Control.Exception (IOException, try)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (toLower)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Maybe (fromMaybe, isNothing)
import Data.Text qualified as Text
import System.Directory (doesFileExist)
import Text.Regex.TDFA ((=~))

withAudio :: (AudioEngine -> IO a) -> IO (Either AudioError a)
withAudio =
  SDL.withAudioSDL

playSound :: AudioEngine -> LoadedSound -> PlaybackParams -> IO (Either AudioError ())
playSound =
  SDL.playSoundSDL

findOutputDevice :: String -> [OutputDevice] -> Either AudioError OutputDevice
findOutputDevice requested devices =
  case filter matches devices of
    device : _ -> Right device
    [] -> Left (AudioDeviceError ("output device not found: " <> requested))
  where
    normalizedRequested =
      normalize requested

    matches OutputDevice {outputDeviceName = OutputDeviceName available} =
      normalize available == normalizedRequested

    normalize = map toLower

listOutputDevices :: IO (Either AudioError [OutputDevice])
listOutputDevices =
  SDL.listOutputDevices

loadSound :: AudioEngine -> SoundSource -> IO (Either AudioError LoadedSound)
loadSound _ source =
  case sourceBytes source <|> lookupEmbeddedSound path of
    Just bytes ->
      pure (Right (loadedSound bytes))
    Nothing -> do
      exists <- doesFileExist path
      if exists
        then do
          result <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
          case result of
            Left err ->
              pure (Left (AudioUnreadableFile path (show err)))
            Right bytes ->
              pure (Right (loadedSound bytes))
        else pure (Left (AudioMissingFile path))
  where
    path = sourcePath source

    loadedSound bytes =
      LoadedSound
        { loadedSoundPath = path,
          loadedSoundBytes = bytes,
          loadedSoundVolume = volumeOrDefault (sourceVolume source)
        }

loadSoundChoice :: SoundSource -> SoundChoice
loadSoundChoice source =
  SoundChoice
    { choiceSound =
        Just
          Sound
            { soundPath = sourcePath source,
              soundBytes = sourceBytes source <|> lookupEmbeddedSound (sourcePath source),
              soundVolume = volumeOrDefault (sourceVolume source)
            },
      choicePlaybackParams = defaultPlaybackParams,
      choiceVariation = identityVariation
    }

nextSequentialFor :: KeyConfigId -> SequentialState -> NonEmpty Sound -> (Sound, SequentialState)
nextSequentialFor keyConfigId (SequentialState entries) sounds =
  (sound, SequentialState nextEntries)
  where
    currentIndex =
      fromMaybe (SequentialIndex 0) (lookup keyConfigId entries)

    (sound, nextIndex) =
      chooseSequential currentIndex sounds

    nextEntries =
      (keyConfigId, nextIndex) : filter ((/= keyConfigId) . fst) entries

soundForEvent :: AppConfig -> KeyEvent -> SoundChoice
soundForEvent appConfig event =
  fromMaybe noSound firstMatchingSound
  where
    (eventKind, eventKeyName) =
      eventDetails event

    firstMatchingSound =
      case matches of
        [] -> Nothing
        (preset, keyConfig, sounds) : _ ->
          Just
            SoundChoice
              { choiceSound = Just (chooseByStrategy (keyConfigStrategy keyConfig) sounds),
                choicePlaybackParams = defaultPlaybackParams,
                choiceVariation =
                  resolveVariation
                    (cliVariation appConfig)
                    (keyConfigVariation keyConfig)
                    (presetVariation preset)
              }
      where
        matches =
          [ (preset, keyConfig, sounds)
            | preset <- appPresets appConfig,
              not (keyDisabled eventKeyName preset),
              keyConfig <- presetKeyConfigs preset,
              keyConfigEvent keyConfig == eventKind,
              keyMatches (keyConfigKeys keyConfig) eventKeyName,
              Just sounds <- [soundsForKeyConfig keyConfig]
          ]

    eventDetails KeyPress =
      (KeyPress, Text.empty)
    eventDetails KeyRelease =
      (KeyRelease, Text.empty)
    eventDetails (KeyPressed observedKeyName) =
      (KeyPress, observedKeyName)
    eventDetails (KeyReleased observedKeyName) =
      (KeyRelease, observedKeyName)

    cliVariation config
      | isNothing (appVolumeVariation config) && isNothing (appTempoVariation config) = Nothing
      | otherwise =
          Just
            SoundVariation
              { soundVariationVolume = appVolumeVariation config,
                soundVariationTempo = appTempoVariation config
              }

    keyDisabled observedKeyName preset =
      observedKeyName `elem` presetDisabledKeys preset

    keyMatches pattern observedKeyName =
      Text.unpack observedKeyName =~ Text.unpack pattern

    chooseByStrategy Nothing sounds =
      chooseFirst sounds
    chooseByStrategy (Just Random) sounds =
      fst (chooseRandom (RandomSeed 0) sounds)
    chooseByStrategy (Just Sequential) sounds =
      fst (chooseSequential (SequentialIndex 0) sounds)

soundsForKeyConfig :: KeyConfig -> Maybe (NonEmpty Sound)
soundsForKeyConfig keyConfig =
  NonEmpty.nonEmpty (map toSound (keyConfigFiles keyConfig))
  where
    toSound file =
      soundFromAudioFile file (lookupEmbeddedSound (audioFilePath file))

chooseFirst :: NonEmpty Sound -> Sound
chooseFirst (sound :| _) =
  sound

chooseSequential :: SequentialIndex -> NonEmpty Sound -> (Sound, SequentialIndex)
chooseSequential (SequentialIndex index) sounds =
  (NonEmpty.toList sounds !! currentIndex, SequentialIndex nextIndex)
  where
    count = NonEmpty.length sounds
    currentIndex = index `mod` count
    nextIndex = (currentIndex + 1) `mod` count

chooseRandom :: RandomSeed -> NonEmpty Sound -> (Sound, RandomSeed)
chooseRandom (RandomSeed seed) sounds =
  (NonEmpty.toList sounds !! index, RandomSeed nextSeed)
  where
    nextSeed = (seed * 1103515245 + 12345) `mod` 2147483648
    index = nextSeed `mod` NonEmpty.length sounds

resolveVariation ::
  Maybe SoundVariation ->
  Maybe SoundVariation ->
  Maybe SoundVariation ->
  SoundVariation
resolveVariation (Just variation) _ _ =
  variation
resolveVariation Nothing (Just variation) _ =
  variation
resolveVariation Nothing Nothing (Just variation) =
  variation
resolveVariation Nothing Nothing Nothing =
  identityVariation

applyVariation :: VariationDirection -> SoundVariation -> Double -> Double
applyVariation direction variation base =
  base * factor
  where
    factor =
      case soundVariationVolume variation of
        Nothing -> 1.0
        Just range ->
          1.0
            + case direction of
              VariationDown -> negate (variationDown range)
              VariationUp -> variationUp range

applyConfiguredVolume :: Double -> Double -> Double
applyConfiguredVolume playbackVolume configuredVolume =
  playbackVolume * configuredVolume

defaultVolume :: Double
defaultVolume =
  1.0

identityVariation :: SoundVariation
identityVariation =
  SoundVariation
    { soundVariationVolume = Nothing,
      soundVariationTempo = Nothing
    }

noSound :: SoundChoice
noSound =
  SoundChoice
    { choiceSound = Nothing,
      choicePlaybackParams = defaultPlaybackParams,
      choiceVariation = identityVariation
    }

soundFromAudioFile :: AudioFile -> Maybe ByteString -> Sound
soundFromAudioFile file bytes =
  Sound
    { soundPath = audioFilePath file,
      soundBytes = bytes,
      soundVolume = volumeOrDefault (audioFileVolume file)
    }

volumeOrDefault :: Maybe Double -> Double
volumeOrDefault =
  fromMaybe defaultVolume
