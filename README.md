<div align="center">

# Bearilo

<h4>Turn your keyboard into a typewriter! 📇</h4>

Written by Keys-i -=[powered by bears]=-

[![Functional purity](https://img.shields.io/endpoint?url=https%3A%2F%2Fkeys-i.github.io%2Fbearilo%2Fbadges%2Fpurity.json)](https://keys-i.github.io/bearilo/badges/purity.json)

```text
      .-------.
     _| ʕ•ᴥ•ʔ |_
   =(_|_______|_)=
     |:::::::::|
     |:::::::[]|
     |o=======.|
     `"""""""""`
```

</div>

## What is Bearilo?

Bearilo is a small Haskell command-line app. It listens for keyboard events and
plays typewriter-style sounds while you type.

It is inspired by Daktilo, but rebuilt in Haskell with a tiny core, boring pure
functions, and bears watching the IO boundary. It is built with Cabal. It is not a Rust crate.

## Project Status

CI runs `cabal build all` and `cabal test all`.

The website workflow publishes this README as a simple GitHub Pages site.

## Getting Started

Run Bearilo with the default preset:

```sh
cabal run exe:bearilo -- --preset default
```

List the bundled presets:

```sh
cabal run exe:bearilo -- --list-presets
```

Use more than one preset if your keyboard needs a small orchestra:

```sh
cabal run exe:bearilo -- -p default -p musicbox
```

## Presets

| Preset | Description |
| --- | --- |
| `default` | classic typewriter press, ding, and release sounds |
| `basic` | a simpler key tap with muted navigation keys |
| `musicbox` | random music-box notes for each press |
| `ducktilo` | duck-flavoured typing |
| `drumkit` | sequential kick, hat, and snare hits |
| `sparks` | crackly electric key sounds |
| `vpaul` | for Paul the GOAT, blessed by bears and lambdas |

## Usage

```sh
bearilo [OPTIONS]
```

Options:

| Option | Meaning |
| --- | --- |
| `-V`, `--verbose` | increase logging verbosity; repeat for more detail |
| `-v`, `--version` | print the Bearilo version |
| `-p`, `--preset PRESET` | select a preset; can be passed more than once |
| `--list-presets` | print bundled and configured presets |
| `--list-devices` | print available output devices |
| `-d`, `--device DEVICE` | select an output device by name |
| `-c`, `--config PATH` | read a specific config file |
| `-i`, `--init` | write the default `bearilo.toml` in the current directory |
| `--variate-volume VALUE` | vary playback volume; pass once or twice |
| `--variate-tempo VALUE` | vary playback tempo; pass once or twice |

Spoiler switch, if surprise bears are not welcome:

```sh
bearilo --no-surprises
```

## Configuration

`--init` writes the default config to `bearilo.toml` in the current directory.
The embedded default lives at `examples/bearilo.toml` in this repo.

Bearilo config is TOML. A preset has a name, key configs, optional disabled
keys, and optional variation.

```toml
[[sound_preset]]
name = "custom"
key_config = [
  { event = "press", keys = "Return", files = [
    { path = "ding.mp3", volume = 1.0 },
  ] },
  { event = "press", keys = ".*", files = [
    { path = "keydown.mp3" },
  ] },
  { event = "release", keys = ".*", files = [
    { path = "keyup.mp3" },
  ] },
]
disabled_keys = ["UpArrow", "DownArrow"]
```

Config fields Bearilo understands:

- `no_surprises`
- `[[sound_preset]]`
- `name`
- `key_config`
- `disabled_keys`
- `variation`
- `event`
- `keys`
- `files`
- `strategy`
- `path`
- `volume`
- `tempo`

Events are `press` and `release`.

Strategies are `random` and `sequential`.

Sound paths can point at normal files. If the file name matches a bundled sound,
Bearilo uses the embedded bytes first.

## Sound Variation

Volume and tempo variation can be set in the config or from the command line.
One value applies both down and up. Two values set the down and up range.

```sh
cabal run exe:bearilo -- --variate-volume 0.1
cabal run exe:bearilo -- --variate-volume 0.1 --variate-volume 0.2
cabal run exe:bearilo -- --variate-tempo 0.05 --variate-tempo 0.1
```

CLI variation wins over key-config variation. Key-config variation wins over
preset variation.

## Supported Platforms

| Platform | Status |
| --- | --- |
| Linux | backend exists; may need permission to read input devices |
| macOS | backend exists; needs Input Monitoring permission |
| Windows | backend exists in source; verify on Windows before release |

Wayland behaviour is not claimed.

## Installation

From this checkout:

```sh
cabal build all
cabal test all
cabal run exe:bearilo -- --help
cabal install exe:bearilo
```

## Build from Source

You need GHC, Cabal, SDL2, and SDL2_mixer development libraries available to
Cabal.

```sh
cabal build all
cabal test all
```

Run without installing:

```sh
cabal run exe:bearilo -- --preset default
```

Install the executable into Cabal's install directory:

```sh
cabal install exe:bearilo
```

## Windows SDL2 Setup

With GHC 9.4.1 and newer on Windows, use SDL2 packages from the MSYS2 CLANG64
environment. Mixing `C:\msys64\mingw64` libraries with the GHCup clang/lld
toolchain can fail while building the Haskell `sdl2` dependency with unresolved
`__stack_chk_fail` and `__stack_chk_guard` symbols, or during Cabal configure
with `Missing C library: ssp`.

Install the matching SDL2 libraries:

```sh
pacman -S mingw-w64-clang-x86_64-SDL2 mingw-w64-clang-x86_64-SDL2_mixer mingw-w64-clang-x86_64-pkgconf
```

Make Cabal point at the same MSYS2 environment. `cabal user-config path` shows
the config file to edit. Replace `C:\msys64` if your MSYS2 root is elsewhere.

```cabal
extra-prog-path: C:\msys64\clang64\bin
                 C:\msys64\usr\bin
extra-include-dirs: C:\msys64\clang64\include
extra-lib-dirs: C:\msys64\clang64\lib
```

After changing the Cabal config, reopen the terminal and run:

```sh
cabal clean
cabal build all
```

If Cabal still reports `Missing C library: ssp`, check that the tools and
libraries Cabal sees all come from `clang64`, not `mingw64`:

```sh
where.exe pkg-config
pkg-config --libs sdl2
```

The first command should resolve through `C:\msys64\clang64\bin` before any
`mingw64` entry. The second command should not include `-lssp`; if it does,
Cabal is still reading SDL2 metadata from the wrong MSYS2 environment.

## macOS Permissions

macOS blocks global keyboard listeners until you allow them.

Grant Input Monitoring permission to the terminal or app that starts Bearilo:

System Settings > Privacy & Security > Input Monitoring

Quit and reopen that terminal after changing the setting.

## Functional Design

Bearilo keeps IO at the edges where it can.

- `Bearilo.Cli` parses options.
- `Bearilo.Config` parses and validates config.
- `Bearilo.Input` classifies keys.
- `Bearilo.Audio` chooses and plays sounds.
- `Bearilo.Os` owns OS keyboard hooks.
- `bridge/` contains C-only platform glue.

The pure pieces are tested without keyboard or audio hardware.

## Acknowledgements

Daktilo by Orhun Parmaksız is the original inspiration for the project. Bearilo
keeps the typewriter idea and takes it for a Haskell walk.

Also acknowledged: Bearilo from Paul the GOAT.

## Contributing

Keep changes small, typed, and testable. Pure decisions should stay pure unless
the operating system makes a very convincing argument.

Before sending changes:

```sh
cabal build all
cabal test all
```

## License

Bearilo is licensed under the MIT license. See `LICENSE`.

## Bear sign-off

λʕ•ᴥ•ʔλ powered by bears, checked by types.
