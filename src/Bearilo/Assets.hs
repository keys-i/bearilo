-- | Embedded config and sound assets.
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
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import System.FilePath (takeFileName)

-- | The default config bundled with Bearilo.
defaultConfigText :: Text
defaultConfigText =
  Text.decodeUtf8 $(embedFile "examples/bearilo.toml")

-- | File names for the bundled sounds.
assetManifest :: NonEmpty FilePath
assetManifest = takeFileName . fst <$> embeddedSounds

-- | Look up an embedded sound by configured file name.
lookupEmbeddedSound :: FilePath -> Maybe ByteString
lookupEmbeddedSound path =
  lookup (takeFileName path) [(takeFileName embeddedPath, bytes) | (embeddedPath, bytes) <- toList embeddedSounds]

embeddedSounds :: NonEmpty (FilePath, ByteString)
embeddedSounds =
  case NonEmpty.nonEmpty $(embedDir "assets/sounds") of
    Just sounds -> sounds
    Nothing -> error "assets/sounds must contain embedded sounds"
