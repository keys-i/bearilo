module Main (main) where

import AppSpec qualified
import AssetsSpec qualified
import AudioSpec qualified
import ConfigSpec qualified
import InputSpec qualified
import LimitSpec qualified
import PackagingSpec qualified

main :: IO ()
main = do
  ConfigSpec.spec
  AssetsSpec.spec
  AudioSpec.spec
  InputSpec.spec
  AppSpec.spec
  LimitSpec.spec
  PackagingSpec.spec
