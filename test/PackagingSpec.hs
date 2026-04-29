module PackagingSpec (spec) where

import Control.Monad (filterM)
import Data.List (isInfixOf, sort)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath (normalise, takeExtension, (</>))

spec :: IO ()
spec = do
  testBridgeFiles
  testFfiBoundary
  testCabalComponents
  testCabalBridgeWiring
  testCabalDoesNotContainReleaseInstallerMetadata
  testExampleConfigPresent
  testReadmeCommands
  testReadmePresets
  testReadmePlatformNotes
  testReadmeReleaseSections

testBridgeFiles :: IO ()
testBridgeFiles = do
  files <- listDirectory "bridge"
  assertEqual
    "bridge contains only OS C bridge files"
    (sort ["linux.c", "linux.h", "darwin.c", "darwin.h", "windows.c", "windows.h"])
    (sort files)
  assertEqual
    "bridge filenames do not contain bridge"
    []
    [file | file <- files, "bridge" `isInfixOf` file]

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
      concat
        <$> traverse
          ( \entry -> do
              let path = root </> entry
              isDirectory <- doesDirectoryExist path
              if isDirectory
                then listHaskellFiles path
                else pure [path | takeExtension path == ".hs"]
          )
          entries

testCabalComponents :: IO ()
testCabalComponents = do
  cabal <- readFile "bearilo.cabal"
  assertContains "cabal has library" "library" cabal
  assertContains "cabal has executable" "executable bearilo" cabal
  assertContains "cabal has test suite" "test-suite bearilo-test" cabal

testCabalBridgeWiring :: IO ()
testCabalBridgeWiring = do
  cabal <- readFile "bearilo.cabal"
  assertContains "linux C source is wired" "c-sources:    bridge/linux.c" cabal
  assertContains "darwin C source is wired" "c-sources:    bridge/darwin.c" cabal
  assertContains "windows C source is wired" "c-sources:    bridge/windows.c" cabal
  assertContains "bridge include dir is wired" "include-dirs: bridge" cabal
  assertNotContains "cabal does not reference bridge/Darwin.h" "bridge/Darwin.h" cabal
  assertNotContains "cabal does not reference bridge/mac.c" "bridge/mac.c" cabal
  assertNotContains "cabal does not reference bridge/mac.h" "bridge/mac.h" cabal

testCabalDoesNotContainReleaseInstallerMetadata :: IO ()
testCabalDoesNotContainReleaseInstallerMetadata = do
  cabal <- readFile "bearilo.cabal"
  assertNotContains "cabal does not mention cargo-dist" "cargo-dist" cabal
  assertNotContains "cabal does not mention wix" "wix" cabal

testExampleConfigPresent :: IO ()
testExampleConfigPresent = do
  exists <- doesFileExist "examples/bearilo.toml"
  assertBool "examples/bearilo.toml exists" exists

testReadmeCommands :: IO ()
testReadmeCommands = do
  readme <- readFile "README.md"
  assertContains "README has install command" "cabal install exe:bearilo" readme
  assertContains "README has build command" "cabal build all" readme
  assertContains "README has test command" "cabal test all" readme
  assertContains "README has local run command" "cabal run bearilo -- --help" readme
  assertContains "README has init manual test" "cabal run bearilo -- --init" readme
  assertContains "README has list-presets manual test" "cabal run bearilo -- --list-presets" readme
  assertContains "README has list-devices manual test" "cabal run bearilo -- --list-devices" readme

testReadmePresets :: IO ()
testReadmePresets = do
  readme <- readFile "README.md"
  assertContains "README has sparks preset" "`sparks`" readme
  assertBool
    "README does not contain standalone spark"
    (not (any (== "spark") (map trimWord (words readme))))
  where
    trimWord =
      filter (`notElem` ("`.,;:()[]#" :: String))

testReadmePlatformNotes :: IO ()
testReadmePlatformNotes = do
  readme <- readFile "README.md"
  assertContains "README has Linux input permission note" "Linux may need permission to read input devices" readme
  assertContains "README has Arch Linux dependency notes" "alsa-lib libxtst libxi" readme
  assertContains "README has Alpine dependency notes" "alsa-lib-dev libxi-dev libxtst-dev" readme
  assertContains "README has Debian dependency notes" "libasound2-dev libxi-dev libxtst-dev" readme
  assertContains "README has event-listening prompt note" "event-listening permission prompt" readme
  assertContains "README has Input Monitoring note" "Input Monitoring" readme
  assertContains "README has Windows implementation note" "Windows support is implemented in source" readme

testReadmeReleaseSections :: IO ()
testReadmeReleaseSections = do
  readme <- readFile "README.md"
  assertContains "README has final parity checklist" "## Final parity checklist" readme
  assertContains "README has release notes" "## Release notes" readme
  assertContains "README has final acceptance checklist" "## Final acceptance checklist" readme

assertContains :: String -> String -> String -> IO ()
assertContains label expected contents =
  assertBool label (expected `isInfixOf` contents)

assertNotContains :: String -> String -> String -> IO ()
assertNotContains label unexpected contents =
  assertBool label (not (unexpected `isInfixOf` contents))

assertBool :: String -> Bool -> IO ()
assertBool _ True = pure ()
assertBool label False = error label

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
