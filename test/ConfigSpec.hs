{-# LANGUAGE OverloadedStrings #-}

module ConfigSpec (spec) where

import Bearilo.Cli (defaultCliOptions, variationFromCliValues)
import Bearilo.Config
import Bearilo.Error
import Bearilo.Types
import Control.Exception (finally)
import Control.Monad (when)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory
  ( createDirectoryIfMissing,
    doesDirectoryExist,
    getTemporaryDirectory,
    removeFile,
    removePathForcibly,
  )
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))

spec :: IO ()
spec = do
  testDefaultConfigParses
  testInvalidTomlFails
  testNoSurprisesDefaultsFalse
  testEventAndStrategyParse
  testEmptyFilesRejected
  testMissingExplicitConfigPath
  testCliVariationSingleValue
  testConfigPathSearchOrder
  testDefaultPresetMerge

testDefaultConfigParses :: IO ()
testDefaultConfigParses = do
  input <- TextIO.readFile "assets/bearilo.toml"
  case parseConfig input of
    Left err -> error ("expected config to parse: " <> show err)
    Right config -> do
      assertBool "expected no_surprises default False" (not (configNoSurprises config))
      assertBool "expected default preset" ("default" `elem` fmap presetName (configSoundPresets config))

testInvalidTomlFails :: IO ()
testInvalidTomlFails =
  case parseConfig "[[not valid" of
    Left (ConfigParseError _) -> pure ()
    other -> error ("expected ConfigParseError, got: " <> show other)

testNoSurprisesDefaultsFalse :: IO ()
testNoSurprisesDefaultsFalse =
  case parseConfig minimalConfigText of
    Right config
      | not (configNoSurprises config) -> pure ()
    other -> error ("expected no_surprises to default False, got: " <> show other)

testEventAndStrategyParse :: IO ()
testEventAndStrategyParse =
  case parseConfig strategyConfigText of
    Right config -> do
      let strategies =
            [ keyConfigStrategy keyConfig
              | preset <- configSoundPresets config,
                keyConfig <- presetKeyConfigs preset
            ]
          events =
            [ keyConfigEvent keyConfig
              | preset <- configSoundPresets config,
                keyConfig <- presetKeyConfigs preset
            ]

      assertBool "expected press event" (KeyPress `elem` events)
      assertBool "expected release event" (KeyRelease `elem` events)
      assertBool "expected random strategy" (Just Random `elem` strategies)
      assertBool "expected sequential strategy" (Just Sequential `elem` strategies)
    other -> error ("expected config to parse strategies, got: " <> show other)

testEmptyFilesRejected :: IO ()
testEmptyFilesRejected = do
  let config =
        Config
          { configNoSurprises = False,
            configSoundPresets =
              [ SoundPreset
                  { presetName = "default",
                    presetDisabledKeys = [],
                    presetVariation = Nothing,
                    presetKeyConfigs =
                      [ KeyConfig
                          { keyConfigEvent = KeyPress,
                            keyConfigKeys = ".*",
                            keyConfigFiles = [],
                            keyConfigStrategy = Nothing,
                            keyConfigVariation = Nothing
                          }
                      ]
                  }
              ]
          }

  case validateConfig config of
    Left (NoAudioFiles "default") -> pure ()
    other -> error ("expected NoAudioFiles, got: " <> show other)

testMissingExplicitConfigPath :: IO ()
testMissingExplicitConfigPath =
  do
    result <- resolveConfigPath (Just "missing-config.toml")
    case result of
      Left (ConfigPathMissing "missing-config.toml") -> pure ()
      other -> error ("expected ConfigPathMissing, got: " <> show other)

testCliVariationSingleValue :: IO ()
testCliVariationSingleValue =
  case variationFromCliValues [0.15] of
    Right VariationRange {variationDown = 0.15, variationUp = 0.15} -> pure ()
    other -> error ("expected duplicated variation range, got: " <> show other)

testConfigPathSearchOrder :: IO ()
testConfigPathSearchOrder = do
  tempRoot <- (</> "bearilo-config-spec") <$> getTemporaryDirectory
  withCleanDirectory tempRoot $
    withEnv "XDG_CONFIG_HOME" tempRoot $ do
      let first = tempRoot </> "bearilo.toml"
          configDir = tempRoot </> "daktilo"
          second = configDir </> "bearilo.toml"
          third = configDir </> "config"

      createDirectoryIfMissing True configDir
      writeFile third ""
      assertResolvedPath third

      writeFile second ""
      assertResolvedPath second

      writeFile first ""
      assertResolvedPath first

      removeFile first
      assertResolvedPath second

      removeFile second
      assertResolvedPath third

testDefaultPresetMerge :: IO ()
testDefaultPresetMerge = do
  let preset =
        SoundPreset
          { presetName = "default",
            presetKeyConfigs = [],
            presetDisabledKeys = [],
            presetVariation = Nothing
          }

      config =
        Config
          { configNoSurprises = False,
            configSoundPresets = [preset]
          }

      options =
        defaultCliOptions

  case mergeConfig options config of
    Right appConfig
      | appPresets appConfig == [preset] -> pure ()
    other -> error ("expected default preset merge, got: " <> show other)

assertResolvedPath :: FilePath -> IO ()
assertResolvedPath expected = do
  result <- resolveConfigPath Nothing
  case result of
    Right actual
      | actual == expected -> pure ()
    other -> error ("expected resolved path " <> expected <> ", got: " <> show other)

assertBool :: String -> Bool -> IO ()
assertBool _ True = pure ()
assertBool message False = error message

withCleanDirectory :: FilePath -> IO a -> IO a
withCleanDirectory path action = do
  exists <- doesDirectoryExist path
  when exists (removePathForcibly path)
  createDirectoryIfMissing True path
  action `finally` removePathForcibly path

withEnv :: String -> String -> IO a -> IO a
withEnv name value action = do
  old <- lookupEnv name
  setEnv name value
  action `finally` restore old
  where
    restore Nothing = unsetEnv name
    restore (Just oldValue) = setEnv name oldValue

minimalConfigText :: Text.Text
minimalConfigText =
  Text.unlines
    [ "[[sound_preset]]",
      "name = \"default\"",
      "key_config = [",
      "  { event = \"press\", keys = \".*\", files = [",
      "    { path = \"keydown.mp3\" },",
      "  ] },",
      "]"
    ]

strategyConfigText :: Text.Text
strategyConfigText =
  Text.unlines
    [ "[[sound_preset]]",
      "name = \"default\"",
      "key_config = [",
      "  { event = \"press\", keys = \".*\", strategy = \"random\", files = [",
      "    { path = \"keydown.mp3\" },",
      "  ] },",
      "  { event = \"release\", keys = \".*\", strategy = \"sequential\", files = [",
      "    { path = \"keyup.mp3\" },",
      "  ] },",
      "]"
    ]
