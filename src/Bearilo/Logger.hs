-- | Tiny logger used by the CLI runtime.
module Bearilo.Logger
  ( LogLevel (..),
    LogMessageLevel (..),
    Logger (..),
    logDebug,
    logInfo,
    logTrace,
    logWarn,
    renderLogLine,
    shouldLog,
    verbosityToLevel,
  )
where

import Bearilo.Output (colorDebug, colorInfo, colorTarget, colorTimestamp, colorTrace, colorWarn)
import Control.Monad (when)
import Data.Time (UTCTime (..), defaultTimeLocale, diffTimeToPicoseconds, formatTime)

-- | How much log output Bearilo should show.
data LogLevel
  = LogWarn
  | LogInfo
  | LogDebug
  | LogTrace
  deriving stock (Eq, Show)

-- | The level of a single log message.
data LogMessageLevel
  = MsgWarn
  | MsgInfo
  | MsgDebug
  | MsgTrace
  deriving stock (Eq, Show)

-- | Runtime bits needed to emit a log line.
data Logger = Logger
  { loggerLevel :: LogLevel,
    loggerNow :: IO UTCTime,
    loggerOutput :: String -> IO (),
    loggerUseColor :: Bool
  }

-- | Turn the CLI verbosity count into a log level.
verbosityToLevel :: Int -> LogLevel
verbosityToLevel verbosity
  | verbosity <= 1 = LogInfo
  | verbosity == 2 = LogDebug
  | otherwise = LogTrace

-- | Decide whether a message should be printed.
shouldLog :: LogLevel -> LogMessageLevel -> Bool
shouldLog level messageLevel =
  messageRank messageLevel <= levelRank level
  where
    levelRank :: LogLevel -> Int
    levelRank LogWarn = 0
    levelRank LogInfo = 1
    levelRank LogDebug = 2
    levelRank LogTrace = 3

    messageRank :: LogMessageLevel -> Int
    messageRank MsgWarn = 0
    messageRank MsgInfo = 1
    messageRank MsgDebug = 2
    messageRank MsgTrace = 3

-- | Render one log line.
--
-- The 'Bool' controls color and keeps tests plain by default.
renderLogLine :: Bool -> UTCTime -> LogMessageLevel -> String -> String
renderLogLine useColor time messageLevel message =
  colorTimestamp useColor timestamp
    <> " "
    <> levelText
    <> " "
    <> colorTarget useColor "bearilo:"
    <> " "
    <> message
  where
    timestamp =
      formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S" time
        <> "."
        <> zeroPad 6 micros
        <> "Z"

    micros =
      diffTimeToPicoseconds (utctDayTime time) `mod` 1000000000000 `div` 1000000

    zeroPad width number =
      replicate (width - length raw) '0' <> raw
      where
        raw = show number

    levelText =
      case messageLevel of
        MsgWarn -> colorWarn useColor (padLeft 5 "WARN")
        MsgInfo -> colorInfo useColor (padLeft 5 "INFO")
        MsgDebug -> colorDebug useColor "DEBUG"
        MsgTrace -> colorTrace useColor "TRACE"

    padLeft width text =
      replicate (max 0 (width - length text)) ' ' <> text

-- | Log an info message.
logInfo :: Logger -> String -> IO ()
logInfo =
  logMessage MsgInfo

-- | Log a warning.
logWarn :: Logger -> String -> IO ()
logWarn =
  logMessage MsgWarn

-- | Log a debug message.
logDebug :: Logger -> String -> IO ()
logDebug =
  logMessage MsgDebug

-- | Log a trace message.
logTrace :: Logger -> String -> IO ()
logTrace =
  logMessage MsgTrace

logMessage :: LogMessageLevel -> Logger -> String -> IO ()
logMessage messageLevel logger message =
  when (shouldLog (loggerLevel logger) messageLevel) $ do
    now <- loggerNow logger
    loggerOutput logger (renderLogLine (loggerUseColor logger) now messageLevel message)
