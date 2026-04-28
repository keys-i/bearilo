module InputSpec (spec) where

import Bearilo.Input
  ( classifyKeyEvent,
    emptyKeyMemory,
    shouldPlayEvent,
    updateKeyMemory,
  )
import Bearilo.Os.Types
  ( RawKeyEvent (..),
    RawKeyState (..),
    mkRawKeyName,
    rawEventFromC,
    rawStateFromCode,
    unRawKeyName,
  )
import Bearilo.Types (KeyEvent (..), KeyMemory (..))

spec :: IO ()
spec = do
  testEmptyRawKeyNameRejected
  testNonEmptyRawKeyNameAccepted
  testPressStateCode
  testReleaseStateCode
  testOtherStateCode
  testFallbackNameForEmptyCName
  testInvalidCodeWithEmptyCNameRejected
  testRawPressConverts
  testRawReleaseConverts
  testRawOtherConvertsToNothing
  testRepeatedPressSuppressed
  testReleaseAllowsNextPress

testEmptyRawKeyNameRejected :: IO ()
testEmptyRawKeyNameRejected =
  assertEqual "empty raw key name is rejected" Nothing (mkRawKeyName "")

testNonEmptyRawKeyNameAccepted :: IO ()
testNonEmptyRawKeyNameAccepted =
  case mkRawKeyName "A" of
    Just keyName ->
      assertEqual "non-empty raw key name is accepted" "A" (unRawKeyName keyName)
    Nothing ->
      error "expected non-empty raw key name"

testPressStateCode :: IO ()
testPressStateCode =
  assertEqual "C state code for press maps to RawPressed" RawPressed (rawStateFromCode 1)

testReleaseStateCode :: IO ()
testReleaseStateCode =
  assertEqual "C state code for release maps to RawReleased" RawReleased (rawStateFromCode 0)

testOtherStateCode :: IO ()
testOtherStateCode =
  assertEqual "C state code for other maps to RawOther" RawOther (rawStateFromCode 2)

testFallbackNameForEmptyCName :: IO ()
testFallbackNameForEmptyCName =
  case rawEventFromC 30 1 (Just "") of
    Just event ->
      assertEqual "empty C name gets fallback key code name" "KeyCode-30" (unRawKeyName (rawKeyName event))
    Nothing ->
      error "expected fallback raw key event"

testInvalidCodeWithEmptyCNameRejected :: IO ()
testInvalidCodeWithEmptyCNameRejected =
  assertEqual
    "empty C name with invalid key code is rejected"
    Nothing
    (rawEventFromC (-1) 1 (Just ""))

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

testRepeatedPressSuppressed :: IO ()
testRepeatedPressSuppressed = do
  let (firstShouldPlay, afterFirstPress) = shouldPlayEvent emptyKeyMemory (KeyPressed "KeyA")
      (secondShouldPlay, _) = shouldPlayEvent afterFirstPress (KeyPressed "KeyA")

  assertEqual "first press plays" True firstShouldPlay
  assertEqual "repeated press before release is suppressed" False secondShouldPlay

testReleaseAllowsNextPress :: IO ()
testReleaseAllowsNextPress = do
  let afterPress = updateKeyMemory emptyKeyMemory (KeyPressed "KeyA")
      afterRelease = updateKeyMemory afterPress (KeyReleased "KeyA")
      (shouldPlay, _) = shouldPlayEvent afterRelease (KeyPressed "KeyA")

  assertEqual "release clears key memory" (KeyMemory []) afterRelease
  assertEqual "press after release plays" True shouldPlay

raw :: String -> RawKeyState -> RawKeyEvent
raw keyName keyState =
  case rawEventFromC 30 stateCode (Just keyName) of
    Just event -> event
    Nothing -> error "expected valid raw key event"
  where
    stateCode =
      case keyState of
        RawPressed -> 1
        RawReleased -> 0
        RawOther -> 2

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual _ expected actual
  | expected == actual = pure ()
assertEqual label expected actual =
  error (label <> ": expected " <> show expected <> ", got " <> show actual)
