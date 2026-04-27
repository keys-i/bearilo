module Bearilo.Cli
  ( CliOptions (..),
    defaultCliOptions,
    parseCli,
    variationFromCliValues,
  )
where

import Bearilo.Types (VariationRange (..))
import Data.Text (Text)

data CliOptions = CliOptions
  { cliPresets :: [Text],
    cliDevice :: Maybe Text,
    cliConfigPath :: Maybe FilePath,
    cliNoSurprises :: Bool,
    cliVolumeVariation :: Maybe VariationRange,
    cliTempoVariation :: Maybe VariationRange
  }
  deriving stock (Eq, Show)

defaultCliOptions :: CliOptions
defaultCliOptions =
  CliOptions
    { cliPresets = [],
      cliDevice = Nothing,
      cliConfigPath = Nothing,
      cliNoSurprises = False,
      cliVolumeVariation = Nothing,
      cliTempoVariation = Nothing
    }

parseCli :: IO CliOptions
parseCli = pure defaultCliOptions

variationFromCliValues :: [Double] -> Either String VariationRange
variationFromCliValues [value] =
  Right VariationRange {variationDown = value, variationUp = value}
variationFromCliValues [down, up] =
  Right VariationRange {variationDown = down, variationUp = up}
variationFromCliValues _ =
  Left "expected one or two variation values"
