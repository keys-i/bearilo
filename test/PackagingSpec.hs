module PackagingSpec (spec) where

import Control.Monad (filterM, forM_)
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
  testDefaultConfigContainsVpaul
  testReadmeCommands
  testReadmePresets
  testReadmeBearVoice
  testReadmeDaktiloOnlyAsInspiration
  testReadmeForbiddenClaims
  testReadmePlatformNotes
  testReadmeSections
  testGithubActionsWorkflows

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

testDefaultConfigContainsVpaul :: IO ()
testDefaultConfigContainsVpaul = do
  config <- readFile "examples/bearilo.toml"
  assertContains "default config has vpaul preset" "name = \"vpaul\"" config
  assertContains "vpaul reuses ding" "path = \"ding.mp3\"" config
  assertContains "vpaul reuses mbox sounds" "path = \"mbox1.mp3\"" config
  assertContains "vpaul reuses keyup" "path = \"keyup.mp3\"" config

testReadmeCommands :: IO ()
testReadmeCommands = do
  readme <- readFile "README.md"
  assertAllContains
    readme
    [ ("README has install command", "cabal install exe:bearilo"),
      ("README has build command", "cabal build all"),
      ("README has test command", "cabal test all"),
      ("README has local run command", "cabal run exe:bearilo -- --help"),
      ("README has preset run command", "cabal run exe:bearilo -- --preset default"),
      ("README has list-presets command", "cabal run exe:bearilo -- --list-presets")
    ]

testReadmePresets :: IO ()
testReadmePresets = do
  readme <- readFile "README.md"
  assertAllContains
    readme
    [ ("README has default preset", "`default`"),
      ("README has basic preset", "`basic`"),
      ("README has musicbox preset", "`musicbox`"),
      ("README has ducktilo preset", "`ducktilo`"),
      ("README has drumkit preset", "`drumkit`"),
      ("README has sparks preset", "`sparks`"),
      ("README has vpaul preset", "`vpaul`")
    ]
  assertBool
    "README does not contain standalone spark"
    (not (any ((== "spark") . trimWord) (words readme)))
  where
    trimWord =
      filter (`notElem` ("`.,;:()[]#" :: String))

testReadmeBearVoice :: IO ()
testReadmeBearVoice = do
  readme <- readFile "README.md"
  assertAllContains
    readme
    [ ("README mentions Keys-i", "Written by Keys-i"),
      ("README mentions powered by bears", "powered by bears"),
      ("README has bear face", "ʕ•ᴥ•ʔ"),
      ("README says Haskell command-line app", "small Haskell command-line app"),
      ("README says IO stays at the edges", "IO at the edges"),
      ("README says built with Cabal", "built with Cabal"),
      ("README says not a Rust crate", "not a Rust crate"),
      ("README has bear sign-off", "λʕ•ᴥ•ʔλ powered by bears, checked by types.")
    ]

testReadmeDaktiloOnlyAsInspiration :: IO ()
testReadmeDaktiloOnlyAsInspiration = do
  readme <- readFile "README.md"
  let daktiloLines = filter ("Daktilo" `isInfixOf`) (lines readme)
  assertBool "README mentions Daktilo" (not (null daktiloLines))
  forM_ daktiloLines $ \line ->
    assertBool
      ("Daktilo mention is inspiration-only: " <> line)
      ("inspired" `isInfixOf` line || "inspiration" `isInfixOf` line)

testReadmeForbiddenClaims :: IO ()
testReadmeForbiddenClaims = do
  readme <- readFile "README.md"
  assertAllNotContains
    readme
    [ ("README does not mention crates.io", "crates.io"),
      ("README does not mention cargo install", "cargo install"),
      ("README does not contain crab line", "respect crables"),
      ("README does not claim Hackage", "Hackage"),
      ("README does not claim Homebrew", "Homebrew"),
      ("README does not claim MSI", "MSI"),
      ("README does not claim MacPorts", "MacPorts"),
      ("README does not claim binary releases", "binary releases"),
      ("README does not claim installers", "installer")
    ]

testReadmePlatformNotes :: IO ()
testReadmePlatformNotes = do
  readme <- readFile "README.md"
  assertAllContains
    readme
    [ ("README has Linux input permission note", "may need permission to read input devices"),
      ("README has macOS Input Monitoring note", "Input Monitoring"),
      ("README has Windows verification note", "verify on Windows before release"),
      ("README does not claim Wayland", "Wayland behaviour is not claimed")
    ]

testReadmeSections :: IO ()
testReadmeSections = do
  readme <- readFile "README.md"
  assertAllContains
    readme
    [ ("README has project header", "# Bearilo"),
      ("README has What is Bearilo", "## What is Bearilo?"),
      ("README has Project Status", "## Project Status"),
      ("README has Getting Started", "## Getting Started"),
      ("README has Presets", "## Presets"),
      ("README has Usage", "## Usage"),
      ("README has Configuration", "## Configuration"),
      ("README has Sound Variation", "## Sound Variation"),
      ("README has Supported Platforms", "## Supported Platforms"),
      ("README has Installation", "## Installation"),
      ("README has Build from Source", "## Build from Source"),
      ("README has macOS Permissions", "## macOS Permissions"),
      ("README has Functional Design", "## Functional Design"),
      ("README has Acknowledgements", "## Acknowledgements"),
      ("README has Contributing", "## Contributing"),
      ("README has License", "## License"),
      ("README has Bear sign-off", "## Bear sign-off")
    ]

testGithubActionsWorkflows :: IO ()
testGithubActionsWorkflows = do
  ciExists <- doesFileExist ".github/workflows/ci.yml"
  websiteExists <- doesFileExist ".github/workflows/website.yml"
  assertBool "CI workflow exists" ciExists
  assertBool "website workflow exists" websiteExists

  ci <- readFile ".github/workflows/ci.yml"
  website <- readFile ".github/workflows/website.yml"
  siteScriptExists <- doesFileExist "scripts/build-site.sh"
  let unsafeRunLines =
        [ line
          | line <- lines ci,
            "cabal run exe:bearilo" `isInfixOf` line,
            not (safeCliLine line)
        ]

  assertAllContains
    website
    [ ("website workflow grants Pages write permission", "pages: write"),
      ("website workflow grants OIDC token permission", "id-token: write"),
      ("website workflow deploys Pages", "actions/deploy-pages")
    ]
  assertBool
    "website script exists if workflow calls it"
    (not ("scripts/build-site.sh" `isInfixOf` website) || siteScriptExists)
  assertNotContains "CI does not run device enumeration" "--list-devices" ci
  assertEqual "CI does not run the normal keyboard listener" [] unsafeRunLines
  where
    safeCliLine line =
      any
        (`isInfixOf` line)
        [ "--help",
          "-- -v",
          "-- --version",
          "--list-presets"
        ]

assertContains :: String -> String -> String -> IO ()
assertContains label expected contents =
  assertBool label (expected `isInfixOf` contents)

assertNotContains :: String -> String -> String -> IO ()
assertNotContains label unexpected contents =
  assertBool label (not (unexpected `isInfixOf` contents))

assertAllContains :: String -> [(String, String)] -> IO ()
assertAllContains contents =
  mapM_ (\(label, expected) -> assertContains label expected contents)

assertAllNotContains :: String -> [(String, String)] -> IO ()
assertAllNotContains contents =
  mapM_ (\(label, unexpected) -> assertNotContains label unexpected contents)

assertBool :: String -> Bool -> IO ()
assertBool _ True = pure ()
assertBool label False = error label

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
