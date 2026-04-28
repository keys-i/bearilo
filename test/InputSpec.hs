{-# LANGUAGE OverloadedStrings #-}

module InputSpec (spec) where

import Bearilo.Input (classifyKeyEvent)
import Bearilo.Os.Types (RawKeyEvent (..), RawKeyName (..), RawKeyState (..))
import Bearilo.Types (KeyEvent (..))
import Data.Text (Text)

spec :: IO ()
spec = do
  testRawPressConverts
  testRawReleaseConverts
  testRawOtherConvertsToNothing
  testEmptyRawKeyNameConvertsToNothing
  testNonEmptyRawKeyNamePreserved

testRawPressConverts :: IO ()
testRawPressConverts =
  assertEqual
    "raw press converts to app KeyPressed"
    (Just (KeyPressed "KeyA"))
    (classifyKeyEvent (raw "KeyA" RawPressed))

testRawReleaseConverts :: IO ()
testRawReleaseConverts =
  assertEqual
    "raw release converts to app KeyReleased"
    (Just (KeyReleased "KeyA"))
    (classifyKeyEvent (raw "KeyA" RawReleased))

testRawOtherConvertsToNothing :: IO ()
testRawOtherConvertsToNothing =
  assertEqual
    "raw other converts to Nothing"
    Nothing
    (classifyKeyEvent (raw "KeyA" RawOther))

testEmptyRawKeyNameConvertsToNothing :: IO ()
testEmptyRawKeyNameConvertsToNothing =
  assertEqual
    "empty raw key name converts to Nothing"
    Nothing
    (classifyKeyEvent (raw "" RawPressed))

testNonEmptyRawKeyNamePreserved :: IO ()
testNonEmptyRawKeyNamePreserved =
  case classifyKeyEvent (raw "Space" RawPressed) of
    Just (KeyPressed name) ->
      assertEqual "non-empty raw key name is preserved" "Space" name
    other ->
      error ("expected KeyPressed Space, got: " <> show other)

raw :: Text -> RawKeyState -> RawKeyEvent
raw keyName keyState =
  RawKeyEvent
    { rawKeyName = RawKeyName keyName,
      rawKeyState = keyState
    }

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
