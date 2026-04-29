-- | Audio loading, playback, and pure sound choice logic.
module Bearilo.Audio
  ( applyConfiguredVolume,
    applyVariation,
    chooseFirst,
    chooseRandom,
    chooseSequential,
    defaultVolume,
    effectivePlaybackParams,
    findOutputDevice,
    listOutputDevices,
    loadSound,
    loadSoundChoice,
    nextSequentialFor,
    playSound,
    resampleNearest,
    resampledLength,
    resolveVariation,
    soundChoicesForEvent,
    soundChoicesForEventWithState,
    soundForEvent,
    soundsForKeyConfig,
    sourceIndexForRate,
    variationPlaybackParams,
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
import Data.Maybe (fromMaybe, isNothing, listToMaybe)
import Data.Text qualified as Text
import System.Directory (doesFileExist)
import Text.Regex.TDFA ((=~))

-- | Open the SDL audio backend for an action.
withAudio :: (AudioEngine -> IO a) -> IO (Either AudioError a)
withAudio =
  SDL.withAudioSDL

-- | Play a loaded sound through the SDL backend.
playSound :: AudioEngine -> LoadedSound -> PlaybackParams -> IO (Either AudioError ())
playSound =
  SDL.playSoundSDL

-- | Find an output device by name, case-insensitively.
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

-- | List available output devices.
listOutputDevices :: IO (Either AudioError [OutputDevice])
listOutputDevices =
  SDL.listOutputDevices

-- | Load a sound from embedded bytes or the configured file path.
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

-- | Build a playable sound choice from a source.
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
      choiceKeyConfig = Nothing,
      choicePlaybackParams = defaultPlaybackParams,
      choiceVariation = identityVariation
    }

-- | Advance sequential playback for one key config.
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

-- | Pick the first sound choice for an event.
soundForEvent :: AppConfig -> KeyEvent -> SoundChoice
soundForEvent appConfig event =
  fromMaybe noSound (listToMaybe (soundChoicesForEvent appConfig event))

-- | Pick sound choices for all matching presets.
soundChoicesForEvent :: AppConfig -> KeyEvent -> [SoundChoice]
soundChoicesForEvent appConfig event =
  fst (soundChoicesForEventWithState appConfig emptySequentialState event)

-- | Pick sound choices while carrying sequential playback state.
soundChoicesForEventWithState :: AppConfig -> SequentialState -> KeyEvent -> ([SoundChoice], SequentialState)
soundChoicesForEventWithState appConfig initialState event =
  foldl chooseForPreset ([], initialState) (zip [0 :: Int ..] (appPresets appConfig))
  where
    (eventKind, eventKeyName) =
      eventDetails event

    chooseForPreset (choices, state) (presetIndex, preset) =
      case matchingConfigs preset of
        [] -> (choices, state)
        (keyConfigIndex, keyConfig, sounds) : _ ->
          let keyConfigId = KeyConfigId (Text.unpack (presetName preset) <> ":" <> show presetIndex <> ":" <> show keyConfigIndex)
              (sound, nextState) = chooseSound state keyConfigId keyConfig sounds
              variation =
                resolveVariation
                  (cliVariation appConfig)
                  (keyConfigVariation keyConfig)
                  (presetVariation preset)
              (playbackParams, _) =
                variationPlaybackParams (RandomSeed (presetIndex * 1000 + keyConfigIndex)) variation defaultPlaybackParams
              choice =
                SoundChoice
                  { choiceSound = Just sound,
                    choiceKeyConfig = Just keyConfig,
                    choicePlaybackParams = playbackParams,
                    choiceVariation = variation
                  }
           in (choices <> [choice], nextState)

    matchingConfigs preset =
      [ (keyConfigIndex, keyConfig, sounds)
        | not (keyDisabled eventKeyName preset),
          not (returnReleaseSuppressed preset),
          (keyConfigIndex, keyConfig) <- zip [0 :: Int ..] (presetKeyConfigs preset),
          keyConfigEvent keyConfig == eventKind,
          keyMatches (keyConfigKeys keyConfig) eventKeyName,
          Just sounds <- [soundsForKeyConfig keyConfig]
      ]

    chooseSound state keyConfigId keyConfig sounds =
      case keyConfigStrategy keyConfig of
        Nothing -> (chooseFirst sounds, state)
        Just Random -> (fst (chooseRandom (RandomSeed 0) sounds), state)
        Just Sequential -> nextSequentialFor keyConfigId state sounds

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

    keyMatches keyPattern observedKeyName =
      Text.unpack observedKeyName =~ Text.unpack keyPattern

    returnReleaseSuppressed preset =
      eventKind == KeyRelease
        && eventKeyName == Text.pack "Return"
        && any isReturnPressConfig (presetKeyConfigs preset)

    isReturnPressConfig keyConfig =
      keyConfigEvent keyConfig == KeyPress
        && keyConfigKeys keyConfig /= Text.pack ".*"
        && keyMatches (keyConfigKeys keyConfig) (Text.pack "Return")

-- | Turn configured files into non-empty sounds when possible.
soundsForKeyConfig :: KeyConfig -> Maybe (NonEmpty Sound)
soundsForKeyConfig keyConfig =
  NonEmpty.nonEmpty (map toSound (keyConfigFiles keyConfig))
  where
    toSound file =
      soundFromAudioFile file (lookupEmbeddedSound (audioFilePath file))

-- | Choose the first configured sound.
chooseFirst :: NonEmpty Sound -> Sound
chooseFirst (sound :| _) =
  sound

-- | Choose the next sound in sequence.
chooseSequential :: SequentialIndex -> NonEmpty Sound -> (Sound, SequentialIndex)
chooseSequential (SequentialIndex index) sounds =
  (NonEmpty.toList sounds !! currentIndex, SequentialIndex nextIndex)
  where
    count = NonEmpty.length sounds
    currentIndex = index `mod` count
    nextIndex = (currentIndex + 1) `mod` count

-- | Choose a deterministic pseudo-random sound from a seed.
chooseRandom :: RandomSeed -> NonEmpty Sound -> (Sound, RandomSeed)
chooseRandom (RandomSeed seed) sounds =
  (NonEmpty.toList sounds !! index, RandomSeed nextSeed)
  where
    nextSeed = (seed * 1103515245 + 12345) `mod` 2147483648
    index = nextSeed `mod` NonEmpty.length sounds

-- | Resolve variation precedence: CLI, then key config, then preset.
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

-- | Apply a volume variation in one direction.
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

-- | Apply volume and tempo variation with a deterministic seed.
variationPlaybackParams :: RandomSeed -> SoundVariation -> PlaybackParams -> (PlaybackParams, RandomSeed)
variationPlaybackParams seed variation params =
  ( params
      { playbackVolume = playbackVolume params * volumeFactor,
        playbackTempo = playbackTempo params * tempoFactor
      },
    seedAfterTempo
  )
  where
    (volumeFactor, seedAfterVolume) =
      variationFactor seed (soundVariationVolume variation)

    (tempoFactor, seedAfterTempo) =
      variationFactor seedAfterVolume (soundVariationTempo variation)

-- | Fold configured sound volume into playback params once.
effectivePlaybackParams :: SoundChoice -> PlaybackParams
effectivePlaybackParams choice =
  case choiceSound choice of
    Nothing -> choicePlaybackParams choice
    Just sound ->
      (choicePlaybackParams choice)
        { playbackVolume = playbackVolume (choicePlaybackParams choice) * soundVolume sound
        }

-- | Apply configured file volume to playback volume.
applyConfiguredVolume :: Double -> Double -> Double
applyConfiguredVolume playbackVolume configuredVolume =
  playbackVolume * configuredVolume

-- | Default volume when config leaves it out.
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
      choiceKeyConfig = Nothing,
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

variationFactor :: RandomSeed -> Maybe VariationRange -> (Double, RandomSeed)
variationFactor seed Nothing =
  (1.0, seed)
variationFactor seed (Just range) =
  (1.0 + unit * (variationDown range + variationUp range) - variationDown range, nextSeed)
  where
    (unit, nextSeed) =
      randomUnit seed

randomUnit :: RandomSeed -> (Double, RandomSeed)
randomUnit (RandomSeed seed) =
  (fromIntegral nextSeed / 2147483648.0, RandomSeed nextSeed)
  where
    nextSeed =
      (seed * 1103515245 + 12345) `mod` 2147483648
