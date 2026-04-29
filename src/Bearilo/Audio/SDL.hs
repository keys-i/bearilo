-- | SDL_mixer audio backend.
module Bearilo.Audio.SDL
  ( listOutputDevices,
    playSoundSDL,
    withAudioSDL,
  )
where

import Bearilo.Audio.Types
import Control.Exception (AsyncException (UserInterrupt), SomeException, bracket_, fromException, try)
import Control.Monad (void)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable (toList, traverse_)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.Maybe (fromMaybe)
import Data.Text qualified as Text
import Data.Word (Word16, Word32)
import Foreign.Ptr (castPtr)
import Foreign.Storable (peek)
import SDL qualified
import SDL.Audio qualified
import SDL.Mixer qualified as Mixer
import SDL.Raw.Mixer qualified as RawMixer
import System.IO.Unsafe (unsafePerformIO)

-- | Open SDL audio, run an action, then close it.
withAudioSDL :: (AudioEngine -> IO a) -> IO (Either AudioError a)
withAudioSDL action = do
  result <- tryAny (bracket_ initializeAudio closeAudio (action engine))
  pure $
    case result of
      Left err
        | isUserInterrupt err -> Left AudioInterrupted
        | otherwise -> Left (AudioInitError (show err))
      Right value -> Right value
  where
    engine =
      AudioEngine
        { audioEnginePlaybackSlots = defaultPlaybackSlots
        }

    initializeAudio = do
      writeIORef playbackChunkCache []
      SDL.initialize [SDL.InitAudio]
      Mixer.initialize [Mixer.InitMP3]
      Mixer.openAudio audioConfig lowLatencyChunkSize
      Mixer.setChannels defaultPlaybackSlots

    closeAudio = do
      void (tryAny (Mixer.halt Mixer.AllChannels))
      freeCachedPlaybackChunks
      Mixer.closeAudio
      Mixer.quit
      SDL.quit

    audioConfig =
      Mixer.Audio
        { Mixer.audioFrequency = s16LeStereoSampleRate,
          Mixer.audioFormat = Mixer.FormatS16_LSB,
          Mixer.audioOutput = Mixer.Stereo
        }

-- | List playback devices through SDL.
listOutputDevices :: IO (Either AudioError [OutputDevice])
listOutputDevices = do
  result <- tryAny enumerateDevices
  pure $
    case result of
      Left err -> Left (AudioDeviceError (show err))
      Right Nothing -> Left (AudioDeviceError "SDL could not enumerate output devices")
      Right (Just devices) -> Right devices
  where
    enumerateDevices =
      bracket_
        (SDL.initialize [SDL.InitAudio])
        SDL.quit
        (fmap toOutputDevices <$> SDL.Audio.getAudioDeviceNames SDL.Audio.ForPlayback)

    toOutputDevices names =
      [ OutputDevice (OutputDeviceName (Text.unpack name))
        | name <- toList names
      ]

-- | Play loaded sound bytes through SDL_mixer.
playSoundSDL :: AudioEngine -> LoadedSound -> PlaybackParams -> IO (Either AudioError ())
playSoundSDL _ loadedSound params =
  case validatePlaybackParams params of
    Left err -> pure (Left err)
    Right () -> do
      chunkResult <- cachedPlaybackChunk loadedSound params
      case chunkResult of
        Left err ->
          pure (Left err)
        Right chunk -> do
          playResult <- tryAny (playChunk chunk)
          pure $
            case playResult of
              Left err -> Left (AudioPlayError (show err))
              Right () -> Right ()
  where
    playChunk chunk = do
      channel <- fromMaybe (toEnum 0) <$> Mixer.getAvailable Mixer.DefaultGroup
      Mixer.setVolume volume channel
      void (Mixer.playOn channel Mixer.Once chunk)

    volume =
      floor (max 0.0 (min 1.0 effectiveVolume) * 128.0)

    effectiveVolume =
      playbackVolume params * loadedSoundVolume loadedSound

cachedPlaybackChunk :: LoadedSound -> PlaybackParams -> IO (Either AudioError Mixer.Chunk)
cachedPlaybackChunk loadedSound params = do
  cache <- readIORef playbackChunkCache
  case lookupCachedChunk cacheKey cache of
    Just chunk ->
      pure (Right chunk)
    Nothing -> do
      chunkResult <- decodePlaybackChunk loadedSound params
      case chunkResult of
        Left err ->
          pure (Left err)
        Right chunk -> do
          Mixer.setVolume 128 chunk
          atomicModifyIORef' playbackChunkCache $ \entries ->
            ((cacheKey, chunk) : entries, ())
          pure (Right chunk)
  where
    cacheKey =
      PlaybackChunkCacheKey
        { cacheSoundPath = loadedSoundPath loadedSound,
          cacheSoundBytes = loadedSoundBytes loadedSound,
          cachePlaybackTempo = playbackTempo params
        }

decodePlaybackChunk :: LoadedSound -> PlaybackParams -> IO (Either AudioError Mixer.Chunk)
decodePlaybackChunk loadedSound params = do
  decodeResult <- decodeLoadedChunk loadedSound
  case decodeResult of
    Left err ->
      pure (Left err)
    Right chunk
      | playbackTempo params == 1.0 ->
          pure (Right chunk)
      | otherwise -> do
          adjusted <- tempoAdjustedChunk loadedSound params chunk
          void (tryAny (Mixer.free chunk))
          pure adjusted

decodeLoadedChunk :: LoadedSound -> IO (Either AudioError Mixer.Chunk)
decodeLoadedChunk loadedSound = do
  decodeResult <- tryAny (Mixer.decode (loadedSoundBytes loadedSound) :: IO Mixer.Chunk)
  pure $
    case decodeResult of
      Left err -> Left (AudioDecodeError (loadedSoundPath loadedSound) (show err))
      Right chunk -> Right chunk

tempoAdjustedChunk :: LoadedSound -> PlaybackParams -> Mixer.Chunk -> IO (Either AudioError Mixer.Chunk)
tempoAdjustedChunk loadedSound params chunk = do
  pcmResult <- tryAny (chunkPcmBytes chunk)
  case pcmResult of
    Left err ->
      pure (Left (AudioDecodeError (loadedSoundPath loadedSound) (show err)))
    Right pcmBytes ->
      case resamplePcmS16LeStereoBytes (playbackTempo params) pcmBytes of
        Left err -> pure (Left err)
        Right adjustedPcm ->
          decodeAdjustedPcm loadedSound adjustedPcm

decodeAdjustedPcm :: LoadedSound -> ByteString.ByteString -> IO (Either AudioError Mixer.Chunk)
decodeAdjustedPcm loadedSound adjustedPcm = do
  decodeResult <- tryAny (Mixer.decode (wavS16LeStereoBytes adjustedPcm) :: IO Mixer.Chunk)
  pure $
    case decodeResult of
      Left err -> Left (AudioDecodeError (loadedSoundPath loadedSound) (show err))
      Right adjustedChunk -> Right adjustedChunk

chunkPcmBytes :: Mixer.Chunk -> IO ByteString.ByteString
chunkPcmBytes (Mixer.Chunk rawChunkPtr) = do
  rawChunk <- peek rawChunkPtr
  ByteString.packCStringLen
    (castPtr (RawMixer.chunkAbuf rawChunk), fromIntegral (RawMixer.chunkAlen rawChunk))

resamplePcmS16LeStereoBytes :: Double -> ByteString.ByteString -> Either AudioError ByteString.ByteString
resamplePcmS16LeStereoBytes tempo pcmBytes
  | ByteString.length pcmBytes `mod` s16LeStereoFrameBytes /= 0 =
      Left
        ( AudioDecodeError
            "decoded PCM"
            "expected signed 16-bit little-endian stereo PCM frame alignment"
        )
  | otherwise =
      ByteString.concat <$> resampleNearest tempo frames
  where
    frames =
      frameAt <$> [0 .. frameCount - 1]

    frameAt index =
      ByteString.take
        s16LeStereoFrameBytes
        (ByteString.drop (index * s16LeStereoFrameBytes) pcmBytes)

    frameCount =
      ByteString.length pcmBytes `div` s16LeStereoFrameBytes

wavS16LeStereoBytes :: ByteString.ByteString -> ByteString.ByteString
wavS16LeStereoBytes pcmBytes =
  LazyByteString.toStrict (Builder.toLazyByteString builder)
  where
    builder =
      Builder.string7 "RIFF"
        <> Builder.word32LE (36 + dataSize)
        <> Builder.string7 "WAVE"
        <> Builder.string7 "fmt "
        <> Builder.word32LE 16
        <> Builder.word16LE 1
        <> Builder.word16LE s16LeStereoChannels
        <> Builder.word32LE s16LeStereoSampleRateWord32
        <> Builder.word32LE byteRate
        <> Builder.word16LE blockAlign
        <> Builder.word16LE s16LeStereoBitsPerSample
        <> Builder.string7 "data"
        <> Builder.word32LE dataSize
        <> Builder.byteString pcmBytes

    dataSize =
      fromIntegral (ByteString.length pcmBytes)

    byteRate =
      s16LeStereoSampleRateWord32
        * fromIntegral blockAlign

    blockAlign =
      s16LeStereoChannels * s16LeStereoBitsPerSample `div` 8

freeCachedPlaybackChunks :: IO ()
freeCachedPlaybackChunks = do
  cachedChunks <- atomicModifyIORef' playbackChunkCache (\entries -> ([], fmap snd entries))
  traverse_ (void . tryAny . Mixer.free) cachedChunks

lookupCachedChunk :: PlaybackChunkCacheKey -> [(PlaybackChunkCacheKey, Mixer.Chunk)] -> Maybe Mixer.Chunk
lookupCachedChunk key =
  lookup key

data PlaybackChunkCacheKey = PlaybackChunkCacheKey
  { cacheSoundPath :: FilePath,
    cacheSoundBytes :: ByteString.ByteString,
    cachePlaybackTempo :: Double
  }
  deriving stock (Eq)

{-# NOINLINE playbackChunkCache #-}
playbackChunkCache :: IORef [(PlaybackChunkCacheKey, Mixer.Chunk)]
playbackChunkCache =
  unsafePerformIO (newIORef [])

lowLatencyChunkSize :: Int
lowLatencyChunkSize =
  256

s16LeStereoSampleRate :: Int
s16LeStereoSampleRate =
  22050

s16LeStereoSampleRateWord32 :: Word32
s16LeStereoSampleRateWord32 =
  fromIntegral s16LeStereoSampleRate

s16LeStereoChannels :: Word16
s16LeStereoChannels =
  2

s16LeStereoBitsPerSample :: Word16
s16LeStereoBitsPerSample =
  16

s16LeStereoFrameBytes :: Int
s16LeStereoFrameBytes =
  fromIntegral (s16LeStereoChannels * s16LeStereoBitsPerSample `div` 8)

tryAny :: IO a -> IO (Either SomeException a)
tryAny =
  try

isUserInterrupt :: SomeException -> Bool
isUserInterrupt err =
  case fromException err of
    Just UserInterrupt -> True
    _ -> False
