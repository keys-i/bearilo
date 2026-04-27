module Bearilo.Assets
  ( defaultConfigText,
    assetManifest,
    lookupEmbeddedSound,
  )
where

import Data.ByteString (ByteString)
import Data.FileEmbed (embedDir, embedFile)
import Data.Foldable (toList)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text.Encoding as Text
import System.FilePath (takeFileName)

defaultConfigText :: Text
defaultConfigText =
  Text.decodeUtf8 $(embedFile "examples/bearilo.toml")

assetManifest :: NonEmpty FilePath
assetManifest = takeFileName . fst <$> embeddedSounds

lookupEmbeddedSound :: FilePath -> Maybe ByteString
lookupEmbeddedSound path =
  lookup (takeFileName path) [(takeFileName embeddedPath, bytes) | (embeddedPath, bytes) <- toList embeddedSounds]

embeddedSounds :: NonEmpty (FilePath, ByteString)
embeddedSounds =
  case NonEmpty.nonEmpty $(embedDir "assets/sounds") of
    Just sounds -> sounds
    Nothing -> error "assets/sounds must contain embedded sounds"
