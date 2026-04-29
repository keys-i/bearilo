-- | Package version text.
module Bearilo.Version
  ( beariloVersion,
  )
where

import Data.Version (showVersion)
import Paths_bearilo qualified as Paths

-- | The version Cabal built into this package.
beariloVersion :: String
beariloVersion =
  showVersion Paths.version
