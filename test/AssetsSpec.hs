module AssetsSpec (spec) where

import Bearilo.Assets
import Bearilo.Config (parseConfig)
import Bearilo.Types
import qualified Data.ByteString as ByteString
import Data.Foldable (toList)
import Data.List (nub)
import System.FilePath (takeFileName)

spec :: IO ()
spec = do
  testDefaultConfigParses
  testDingEmbedded
  testMissingSound
  testManifestCoversConfig

testDefaultConfigParses :: IO ()
testDefaultConfigParses =
  case parseConfig defaultConfigText of
    Left err -> error ("expected embedded default config to parse: " <> show err)
    Right _ -> pure ()

testDingEmbedded :: IO ()
testDingEmbedded =
  case lookupEmbeddedSound "ding.mp3" of
    Just bytes
      | not (ByteString.null bytes) -> pure ()
    other -> error ("expected embedded ding.mp3 bytes, got: " <> show other)

testMissingSound :: IO ()
testMissingSound =
  case lookupEmbeddedSound "missing.mp3" of
    Nothing -> pure ()
    Just _ -> error "expected missing.mp3 to be absent"

testManifestCoversConfig :: IO ()
testManifestCoversConfig =
  case parseConfig defaultConfigText of
    Left err -> error ("expected config to parse: " <> show err)
    Right config -> do
      let manifest = toList assetManifest
          referenced = nub (map takeFileName (configSoundFiles config))
          missing = filter (`notElem` manifest) referenced

      if null missing
        then pure ()
        else error ("assetManifest missing files: " <> show missing)
  where
    configSoundFiles :: Config -> [FilePath]
    configSoundFiles config =
      [ audioFilePath file
        | preset <- configSoundPresets config,
          keyConfig <- presetKeyConfigs preset,
          file <- keyConfigFiles keyConfig
      ]
