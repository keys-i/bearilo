module PackagingSpec (spec) where

import Control.Monad (filterM)
import Data.List (isInfixOf, sort)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (normalise, takeExtension, (</>))

spec :: IO ()
spec = do
  testBridgeFiles
  testFfiBoundary

testBridgeFiles :: IO ()
testBridgeFiles = do
  files <- listDirectory "bridge"
  assertEqual
    "bridge contains only OS C bridge files"
    (sort ["linux.c", "linux.h", "darwin.c", "darwin.h", "windows.c", "windows.h"])
    (sort files)

testFfiBoundary :: IO ()
testFfiBoundary = do
  files <- listHaskellFiles "src"
  offenders <- filterM hasForbiddenForeignImport files
  assertEqual "only Bearilo.Os.* imports C functions" [] offenders
  where
    allowed =
      map
        normalise
        [ "src/Bearilo/Os/Linux.hs",
          "src/Bearilo/Os/Darwin.hs",
          "src/Bearilo/Os/Windows.hs"
        ]

    hasForbiddenForeignImport path = do
      contents <- readFile path
      pure ("foreign import" `isInfixOf` contents && normalise path `notElem` allowed)

    listHaskellFiles root = do
      entries <- listDirectory root
      fmap concat $
        traverse
          ( \entry -> do
              let path = root </> entry
              isDirectory <- doesDirectoryExist path
              if isDirectory
                then listHaskellFiles path
                else pure [path | takeExtension path == ".hs"]
          )
          entries

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
