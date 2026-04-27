module PackagingSpec (spec) where

import Data.List (sort)
import System.Directory (listDirectory)

spec :: IO ()
spec = pure ()

checkMain :: IO ()
checkMain = do
  actual <- readFile "app/Main.hs"
  let expected =
        unlines
          [ "module Main (main) where",
            "",
            "import qualified Bearilo.App as App",
            "",
            "main :: IO ()",
            "main = App.run"
          ]

  if actual == expected
    then pure ()
    else error "app/Main.hs must only call App.run"

checkBridge :: IO ()
checkBridge = do
  actual <- sort <$> listDirectory "bridge"

  let expected =
        sort
          [ "linux.c",
            "linux.h",
            "mac.c",
            "mac.h",
            "windows.c",
            "windows.h"
          ]

  if actual == expected
    then pure ()
    else error "bridge/ contains wrong files"
