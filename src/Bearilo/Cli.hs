module Bearilo.Cli (CliOptions (..), parseCli) where

data CliOptions = CliOptions
  deriving stock (Eq, Show)

parseCli :: IO CliOptions
parseCli = pure CliOptions
