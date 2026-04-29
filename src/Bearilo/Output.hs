-- | Small terminal rendering helpers.
--
-- Color is controlled by a plain 'Bool' so it stays easy to turn off.
module Bearilo.Output
  ( beariloAsciiArt,
    beariloHelpText,
    colorBanner,
    colorDebug,
    colorDeviceName,
    colorHeader,
    colorInfo,
    colorTarget,
    colorTimestamp,
    colorTrace,
    colorWarn,
    renderChoiceKeyConfig,
    renderConfigSummary,
    renderDeviceList,
    renderPlaybackParams,
    renderPresetList,
  )
where

import Bearilo.Audio.Types (OutputDevice (..), OutputDeviceName (..), PlaybackParams (..), SoundChoice (..), Sound (..))
import Bearilo.Types
import Data.List (intercalate, transpose)
import Data.Maybe (maybeToList)
import Data.Text qualified as Text
import Numeric (showFFloat)
import System.Console.ANSI
  ( Color (..),
    ColorIntensity (..),
    ConsoleIntensity (..),
    ConsoleLayer (..),
    SGR (..),
    setSGRCode,
  )

-- | The little Bearilo footer art.
beariloAsciiArt :: String
beariloAsciiArt =
  unlines
    [ "      .-------.",
      "     _| ʕ•ᴥ•ʔ |_",
      "   =(_|_______|_)=",
      "     |:::::::::|",
      "     |:::::::[]|",
      "     |o=======.|",
      "     `\"\"\"\"\"\"\"\"\"`"
    ]

-- | Text shown at the top of generated help.
beariloHelpText :: Bool -> String
beariloHelpText useColor =
  unlines
    [ colorBanner useColor "Bearilo - keyboard sounds for typing.",
      "",
      "Turn your keyboard into a typewriter! 📇",
      "",
      "Written by Keys-i -=[powered by bears]=-",
      colorBanner useColor beariloAsciiArt
    ]

-- | Render the available presets.
renderPresetList :: Bool -> [SoundPreset] -> String
renderPresetList _ [] =
  "No presets found.\n"
renderPresetList useColor presets =
  unlines (concatMap renderPreset presets)
  where
    renderPreset preset =
      [ "[" <> Text.unpack (presetName preset) <> "]",
        colorHeader useColor (head renderedRows),
        renderedRows !! 1
      ]
        <> drop 2 renderedRows
        <> [""]
      where
        renderedRows =
          renderRows columnGap (headers : separator : map keyConfigRow (presetKeyConfigs preset))

    headers =
      ["Event", "Keys", "File"]

    separator =
      ["-----", "----", "----"]

    keyConfigRow keyConfig =
      [ eventLabel (keyConfigEvent keyConfig),
        Text.unpack (keyConfigKeys keyConfig),
        intercalate "," (map audioFilePath (keyConfigFiles keyConfig))
      ]

    columnGap =
      "    "

-- | Render output devices for --list-devices.
renderDeviceList :: Bool -> [OutputDevice] -> String
renderDeviceList _ [] =
  "No output devices found.\n"
renderDeviceList useColor devices =
  unlines
    [ "• " <> colorDeviceName useColor name
      | OutputDevice {outputDeviceName = OutputDeviceName name} <- devices
    ]

-- | Render config in a shape a human can scan.
renderConfigSummary :: Bool -> String -> Config -> String
renderConfigSummary useColor sourceLabel config =
  unlines $
    [ colorHeader useColor "Config",
      "  source: " <> sourceLabel,
      "  no_surprises: " <> boolLabel (configNoSurprises config),
      "  presets: " <> show (length (configSoundPresets config))
    ]
      <> concatMap renderPresetSummary (configSoundPresets config)
  where
    renderPresetSummary preset =
      [ "",
        "  " <> colorHeader useColor ("[" <> Text.unpack (presetName preset) <> "]"),
        "    disabled: " <> disabledKeys
      ]
        <> map ("    " <>) renderedKeyConfigs
      where
        disabledKeys =
          case presetDisabledKeys preset of
            [] -> "none"
            keys -> intercalate ", " (map Text.unpack keys)

        renderedKeyConfigs =
          renderRows
            "    "
            [ [ eventLabel (keyConfigEvent keyConfig),
                Text.unpack (keyConfigKeys keyConfig),
                intercalate "," (map audioFilePath (keyConfigFiles keyConfig)),
                keyConfigDetails keyConfig
              ]
              | keyConfig <- presetKeyConfigs preset
            ]

    keyConfigDetails keyConfig =
      unwords . filter (not . null) $
        maybeToList (strategyLabel <$> keyConfigStrategy keyConfig)
          <> maybeToList (variationLabel <$> keyConfigVariation keyConfig)

    boolLabel True = "true"
    boolLabel False = "false"

-- | Render the matched key config for debug logs.
renderChoiceKeyConfig :: SoundChoice -> String
renderChoiceKeyConfig choice =
  case choiceKeyConfig choice of
    Nothing -> "none"
    Just keyConfig ->
      eventShortLabel (keyConfigEvent keyConfig)
        <> " "
        <> Text.unpack (keyConfigKeys keyConfig)
        <> " -> "
        <> maybe "none" soundPath (choiceSound choice)

-- | Render playback params for debug logs.
renderPlaybackParams :: PlaybackParams -> String
renderPlaybackParams params =
  "Volume: "
    <> renderNumber (playbackVolume params)
    <> ", Tempo: "
    <> renderNumber (playbackTempo params)

-- | Color the program name or ASCII banner.
colorBanner :: Bool -> String -> String
colorBanner =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Yellow]

-- | Color a table header.
colorHeader :: Bool -> String -> String
colorHeader =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Cyan]

-- | Color an info level.
colorInfo :: Bool -> String -> String
colorInfo =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Green]

-- | Color a warning level.
colorWarn :: Bool -> String -> String
colorWarn =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Yellow]

-- | Color a debug level.
colorDebug :: Bool -> String -> String
colorDebug =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Magenta]

-- | Color a trace level.
colorTrace :: Bool -> String -> String
colorTrace =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid Blue]

-- | Color timestamps.
colorTimestamp :: Bool -> String -> String
colorTimestamp =
  withColor [SetColor Foreground Dull White]

-- | Color the log target.
colorTarget :: Bool -> String -> String
colorTarget =
  withColor [SetColor Foreground Dull White]

-- | Color device names in --list-devices.
colorDeviceName :: Bool -> String -> String
colorDeviceName =
  withColor [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid White]

renderRows :: String -> [[String]] -> [String]
renderRows _ [] =
  []
renderRows gap rows =
  map renderRow rows
  where
    widths =
      map (maximum . map length) (transpose rows)

    renderRow cells =
      intercalate gap (zipWith padRight widths cells)

    padRight width text =
      text <> replicate (max 0 (width - length text)) ' '

eventLabel :: KeyEvent -> String
eventLabel KeyPress = "Key Press"
eventLabel KeyRelease = "Key Release"
eventLabel (KeyPressed _) = "Key Press"
eventLabel (KeyReleased _) = "Key Release"

eventShortLabel :: KeyEvent -> String
eventShortLabel KeyPress = "press"
eventShortLabel KeyRelease = "release"
eventShortLabel (KeyPressed _) = "press"
eventShortLabel (KeyReleased _) = "release"

strategyLabel :: PlaybackStrategy -> String
strategyLabel Random = "strategy random"
strategyLabel Sequential = "strategy sequential"

variationLabel :: SoundVariation -> String
variationLabel variation =
  unwords ("variation" : volumePart <> tempoPart)
  where
    volumePart =
      maybeToList (("volume " <>) . rangeLabel <$> soundVariationVolume variation)

    tempoPart =
      maybeToList (("tempo " <>) . rangeLabel <$> soundVariationTempo variation)

rangeLabel :: VariationRange -> String
rangeLabel range
  | variationDown range == variationUp range =
      "±" <> renderRangeNumber (variationUp range)
  | otherwise =
      "-" <> renderRangeNumber (variationDown range) <> "/+" <> renderRangeNumber (variationUp range)

renderRangeNumber :: Double -> String
renderRangeNumber number =
  showFFloat (Just 2) number ""

renderNumber :: Double -> String
renderNumber number =
  dropTrailingDot (dropTrailingZeros (showFFloat (Just 6) number ""))
  where
    dropTrailingZeros text =
      case reverse text of
        '0' : rest -> dropTrailingZeros (reverse rest)
        _ -> text

    dropTrailingDot text =
      case reverse text of
        '.' : rest -> reverse rest
        _ -> text

withColor :: [SGR] -> Bool -> String -> String
withColor _ False text =
  text
withColor sgr True text =
  setSGRCode sgr <> text <> setSGRCode [Reset]
