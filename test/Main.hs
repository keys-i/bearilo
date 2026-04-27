module Main (main) where

import qualified AssetsSpec
import qualified AudioSpec
import qualified ConfigSpec
import qualified InputSpec
import qualified LimitSpec
import qualified PackagingSpec

main :: IO ()
main = do
    ConfigSpec.spec
    AssetsSpec.spec
    AudioSpec.spec
    InputSpec.spec
    LimitSpec.spec
    PackagingSpec.spec
