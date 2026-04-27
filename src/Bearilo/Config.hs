module Bearilo.Config (Config (..), parseConfig, validateConfig) where

import Bearilo.Types (Config (..))

parseConfig :: String -> Either String Config
parseConfig _ = Right Config

validateConfig :: Config -> Either String Config
validateConfig = Right
