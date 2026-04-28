# TODO

This TODO is based only on files inspected in `../daktilo`.
Items without a source note are structural rewrite tasks, not claims about Rust behaviour.

> **Limit:** This file is not a feature wishlist. Anything not proven from `../daktilo` stays out or goes under `Unknown from source`.

## Project structure

```text
bearilo/
├── bearilo.cabal
├── cabal.project
├── README.md
├── TODO.md
├── app/
│   └── Main.hs
├── src/
│   └── Bearilo/
│       ├── App.hs
│       ├── Cli.hs
│       ├── Config.hs
│       ├── Assets.hs
│       ├── Audio.hs
│       ├── Input.hs
│       ├── Error.hs
│       ├── Types.hs
│       ├── Audio/
│       │   ├── Types.hs
│       │   └── SDL.hs
│       └── Os/
│           ├── Types.hs
│           ├── Linux.hs
│           ├── Darwin.hs
│           └── Windows.hs
├── bridge/
│   ├── linux.c
│   ├── linux.h
│   ├── Darwin.c
│   ├── Darwin.h
│   ├── windows.c
│   └── windows.h
├── assets/
│   ├── bearilo.toml
│   └── sounds/
└── test/
    ├── Main.hs
    ├── ConfigSpec.hs
    ├── AssetsSpec.hs
    ├── AudioSpec.hs
    ├── InputSpec.hs
    ├── LimitationSpec.hs
    └── PackagingSpec.hs
```

> **OS boundary:** `Bearilo.Os.*` is the only Haskell layer that touches C. `bridge/` contains only C and header files.

> **Do not:** Do not create `bridge_bridge.c`, `linux_bridge.c`, `Darwin_bridge.c`, or `windows_bridge.c`.

| Path                         | Purpose                                               |
| ---------------------------- | ----------------------------------------------------- |
| `app/Main.hs`                | Calls `App.run`.                                      |
| `src/Bearilo/App.hs`         | Wires CLI, config, audio, OS input, and runtime loop. |
| `src/Bearilo/Cli.hs`         | Parses CLI flags and env vars.                        |
| `src/Bearilo/Config.hs`      | Parses, validates, resolves, and merges config.       |
| `src/Bearilo/Assets.hs`      | Exposes embedded config and sounds.                   |
| `src/Bearilo/Audio.hs`       | Public audio API.                                     |
| `src/Bearilo/Audio/Types.hs` | Audio-only types.                                     |
| `src/Bearilo/Audio/SDL.hs`   | SDL audio backend.                                    |
| `src/Bearilo/Input.hs`       | Pure key classification and key state rules.          |
| `src/Bearilo/Os/Types.hs`    | Raw OS key event types.                               |
| `src/Bearilo/Os/Linux.hs`    | Linux FFI wrapper.                                    |
| `src/Bearilo/Os/Darwin.hs`   | DarwinOS FFI wrapper.                                 |
| `src/Bearilo/Os/Windows.hs`  | Windows FFI wrapper.                                  |
| `bridge/linux.c`             | Linux C hook implementation.                          |
| `bridge/linux.h`             | Linux C hook header.                                  |
| `bridge/Darwin.c`            | DarwinOS C hook implementation.                       |
| `bridge/Darwin.h`            | DarwinOS C hook header.                               |
| `bridge/windows.c`           | Windows C hook implementation.                        |
| `bridge/windows.h`           | Windows C hook header.                                |
| `config/bearilo.toml`        | Embedded default config copied from source.           |
| `assets/sounds/`             | Embedded MP3 assets copied from source.               |
| `test/*Spec.hs`              | Focused Hspec tests.                                  |

## Source facts

> **Source mismatch:** README lists preset `spark`, but `config/bearilo.toml` defines `sparks`. Use `sparks` unless code proves otherwise.

| Area              | Fact                                                                                                                                                                                                      | Source                                                                                                                                                                                                              |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Workspace         | Rust has a workspace with `daktilo` CLI crate and `daktilo_lib` library crate.                                                                                                                            | `Cargo.toml`, `crates/daktilo/Cargo.toml`, `crates/daktilo_lib/Cargo.toml`                                                                                                                                          |
| CLI flags         | CLI options are `--verbose`, `--preset`, `--list-presets`, `--list-devices`, `--device`, `--config`, `--init`, hidden `--no-surprises`, `--variate-volume`, `--variate-tempo`, `--help`, and `--version`. | `crates/daktilo/src/args.rs`, `README.md`                                                                                                                                                                           |
| CLI subcommands   | CLI has no subcommands in `Args`.                                                                                                                                                                         | `crates/daktilo/src/args.rs`                                                                                                                                                                                        |
| CLI env           | CLI env names are `VERBOSE`, `PRESET`, `DAKTILO_DEVICE`, `DAKTILO_CONFIG`, `DAKTILO_VOLUME`, and `DAKTILO_TEMPO`.                                                                                         | `crates/daktilo/src/args.rs`, `README.md`                                                                                                                                                                           |
| Init              | `--init` writes embedded `config/bearilo.toml` to `bearilo.toml` in the current directory.                                                                                                                | `crates/daktilo/src/main.rs`, `crates/daktilo_lib/src/embed.rs`, `crates/daktilo_lib/src/config.rs`                                                                                                                 |
| Config path       | Config search order is `<config_dir>/bearilo.toml`, `<config_dir>/daktilo/bearilo.toml`, `<config_dir>/daktilo/config`.                                                                                   | `crates/daktilo_lib/src/config.rs`, `README.md`                                                                                                                                                                     |
| Config fallback   | Missing selected config path falls back to embedded default config.                                                                                                                                       | `crates/daktilo/src/main.rs`                                                                                                                                                                                        |
| Config format     | Config format uses TOML `sound_preset`, `name`, `key_config`, `event`, `keys`, `files`, `path`, `volume`, `strategy`, `disabled_keys`, `variation`, and `no_surprises`.                                   | `crates/daktilo_lib/src/config.rs`, `config/bearilo.toml`, `README.md`                                                                                                                                              |
| Presets           | Built-in preset names are `default`, `basic`, `musicbox`, `ducktilo`, `drumkit`, and `sparks`.                                                                                                            | `config/bearilo.toml`                                                                                                                                                                                               |
| Preset mismatch   | README lists preset `spark`, while default config defines `sparks`.                                                                                                                                       | `README.md`, `config/bearilo.toml`                                                                                                                                                                                  |
| Embedded assets   | Embedded sound assets come from `sounds/`; embedded config comes from `config/`.                                                                                                                          | `crates/daktilo_lib/src/embed.rs`                                                                                                                                                                                   |
| Sound loading     | Sound loading tries embedded bytes by configured path first, then opens the configured path as a file.                                                                                                    | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Audio sinks       | Audio creates 8 sinks per preset and stops a sink before appending the next sound to it.                                                                                                                  | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Output device     | Output device selection uses the default output device unless `--device` is set.                                                                                                                          | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Device matching   | Named output device matching lowercases the device name but not the requested CLI value.                                                                                                                  | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Keyboard listener | Keyboard input uses `rdev::listen` in a spawned thread and sends events through a Tokio unbounded channel.                                                                                                | `crates/daktilo_lib/src/lib.rs`                                                                                                                                                                                     |
| Event types       | App handles only key press and key release events.                                                                                                                                                        | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Disabled keys     | Disabled keys skip both key press and key release handling.                                                                                                                                               | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Key matching      | Key matching uses regexes against the debug string of the key.                                                                                                                                            | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Config matching   | First matching `KeyConfig` wins for a key event.                                                                                                                                                          | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Key press         | Key press plays only when the previous tracked state is released.                                                                                                                                         | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Key release       | Key release plays when a matching release config exists and then marks state released.                                                                                                                    | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Playback strategy | Playback strategy `random` picks a random configured file; `sequential` uses one app-level `file_index`; missing strategy uses the first file.                                                            | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Volume            | Volume defaults to `1.0`; missing variation factor defaults to `1.0`.                                                                                                                                     | `crates/daktilo_lib/src/app.rs`                                                                                                                                                                                     |
| Variation         | Variation precedence is CLI variation, then `key_config` variation, then preset variation.                                                                                                                | `crates/daktilo_lib/src/app.rs`, `README.md`                                                                                                                                                                        |
| Hidden preset     | Hidden preset selection returns `mbox10.mp3`, `mbox11.mp3`, and `mbox9.mp3` when random hits `42` out of `0..1000` with surprises enabled, or whenever preset name is `ak47`.                             | `crates/daktilo_lib/src/config.rs`                                                                                                                                                                                  |
| Logging           | Verbose count maps to `INFO`, `DEBUG`, then `TRACE`.                                                                                                                                                      | `crates/daktilo/src/main.rs`, `crates/daktilo_lib/src/logger.rs`                                                                                                                                                    |
| Errors            | Error cases include IO, audio stream, decode, play, devices, device name, device not found, embedded content, log directive parse, TOML parse, UTF-8, preset not found, no audio files, and regex parse.  | `crates/daktilo_lib/src/error.rs`                                                                                                                                                                                   |
| Tests             | Inline tests cover clap debug assert, completion generation, manpage generation, config parse, embedded config parse, and IO error formatting.                                                            | `crates/daktilo/src/args.rs`, `crates/daktilo/src/bin/completions.rs`, `crates/daktilo/src/bin/mangen.rs`, `crates/daktilo_lib/src/config.rs`, `crates/daktilo_lib/src/embed.rs`, `crates/daktilo_lib/src/error.rs` |
| Platforms         | README marks Linux X11, Windows, and DarwinOS as supported and Wayland as unchecked.                                                                                                                      | `README.md`                                                                                                                                                                                                         |
| DarwinOS          | README says DarwinOS needs Input Monitoring permission for the terminal application.                                                                                                                      | `README.md`                                                                                                                                                                                                         |
| Linux packages    | Linux packages listed are `alsa-lib libxtst libxi`, `alsa-lib-dev libxi-dev libxtst-dev`, and `libasound2-dev libxi-dev libxtst-dev`.                                                                     | `README.md`, `crates/daktilo/Cargo.toml`                                                                                                                                                                            |

## Unknown from source

> **Limit:** Unknowns are not tasks. Do not implement them unless later source proves them.

| Area                      | Unknown                                                                                    | Notes                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| Docs                      | Could not verify `../daktilo/docs/**`.                                                     | No `docs/` directory was found.                                |
| Examples                  | Could not verify `../daktilo/examples/**`.                                                 | No `examples/` directory was found.                            |
| Tests                     | Could not verify `../daktilo/tests/**`.                                                    | No top-level or crate `tests/` directory was found.            |
| Top-level src             | Could not verify `../daktilo/src/**`.                                                      | No top-level `src/` directory was found.                       |
| Theme loading             | Could not verify theme loading.                                                            | No theme config field, theme loader, or theme asset was found. |
| OS hooks                  | Could not verify per-OS keyboard hook implementation from source.                          | Source calls `rdev::listen`.                                   |
| Wayland                   | Could not verify Wayland keyboard behaviour in code.                                       | README marks Wayland unchecked.                                |
| Invalid TOML tests        | Could not verify tests for invalid TOML.                                                   | No matching test was found.                                    |
| Missing config tests      | Could not verify tests for explicit missing config path.                                   | No matching test was found.                                    |
| Missing sound tests       | Could not verify tests for missing sound files.                                            | No matching test was found.                                    |
| Disabled key tests        | Could not verify tests for disabled keys.                                                  | No matching test was found.                                    |
| Random playback tests     | Could not verify tests for random playback selection.                                      | No matching test was found.                                    |
| Sequential playback tests | Could not verify tests for sequential playback selection.                                  | No matching test was found.                                    |
| Key release tests         | Could not verify tests for key release playback.                                           | No matching test was found.                                    |
| Config path tests         | Could not verify tests for config path discovery.                                          | No matching test was found.                                    |
| Embedded sound tests      | Could not verify tests for embedded sound manifest.                                        | No matching test was found.                                    |
| Windows runtime           | Could not verify Windows permission or runtime requirements beyond the README support row. | No extra source was found.                                     |
| Bearilo config name       | Could not verify a Bearilo-specific config filename.                                       | Rust uses `bearilo.toml`.                                      |

## v0.1.0 — project skeleton

- [x] Create the tree shown in `## Project structure`.
- [x] Create `cabal.project` with `packages: .`.
- [x] Create `bearilo.cabal` with `executable bearilo`, `library`, and `test-suite bearilo-test`.
- [x] Set `default-language: GHC2021` in `bearilo.cabal`.
- [x] Add `app/Main.hs` with only `main = App.run`.
- [x] Add placeholder modules with exports matching their file purpose table.
- [x] Add placeholder C and header files in `bridge/` using only the listed filenames.
- [x] Add `test/Main.hs` and focused empty spec files from the project tree.
- [x] Test that `app/Main.hs` contains only the `App.run` call.
- [x] Test that `bridge/` contains only `linux.c`, `linux.h`, `Darwin.c`, `Darwin.h`, `windows.c`, and `windows.h`.
- [x] Acceptance: `cabal build` and `cabal test` run against the empty skeleton.

## v0.2.0 — config

- [x] Create `src/Bearilo/Types.hs` types `Config`, `SoundPreset`, `KeyConfig`, `KeyEvent`, `AudioFile`, `PlaybackStrategy`, and `SoundVariation`. Source: `crates/daktilo_lib/src/config.rs`.
- [x] Create `src/Bearilo/Config.hs` with `parseConfig :: Text -> Either ConfigError Config`. Source: `crates/daktilo_lib/src/config.rs`.
- [x] Parse TOML `[[sound_preset]]` arrays and `no_surprises` default `False`. Source: `crates/daktilo_lib/src/config.rs`, `config/bearilo.toml`.
- [x] Parse `event = "press"` and `event = "release"` into `KeyPress` and `KeyRelease`. Source: `crates/daktilo_lib/src/config.rs`, `README.md`.
- [x] Parse `strategy = "random"` and `strategy = "sequential"` into `Random` and `Sequential`. Source: `crates/daktilo_lib/src/config.rs`, `README.md`.
- [x] Add `validateConfig :: Config -> Either ConfigError ValidConfig` and reject empty `files` before playback because Rust raises `NoAudioFiles` inside `pick_sound_file`. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Add `resolveConfigPath :: Maybe FilePath -> IO (Either ConfigError FilePath)` with source search order. Source: `crates/daktilo_lib/src/config.rs`, `README.md`.
- [x] Return `ConfigPathMissing FilePath` for an explicit missing path because Rust falls back to embedded default for any missing selected path in `crates/daktilo/src/main.rs`. Source: `crates/daktilo/src/main.rs`.
- [x] Add `mergeConfig :: CliOptions -> Config -> Either ConfigError AppConfig` for presets, device, no-surprises, and variation overrides. Source: `crates/daktilo/src/main.rs`, `crates/daktilo_lib/src/app.rs`.
- [x] Test `parseConfig` against `config/bearilo.toml` copied from source config. Source: `config/bearilo.toml`.
- [x] Test invalid TOML returns `ConfigParseError`. Source: `crates/daktilo_lib/src/error.rs`.
- [x] Test missing explicit config path returns `ConfigPathMissing`. Source: `crates/daktilo/src/main.rs`.
- [x] Test one-value variation CLI input duplicates the value into up and down. Source: `crates/daktilo/src/args.rs`.
- [x] Test config path search order with temporary config dirs. Source: `crates/daktilo_lib/src/config.rs`.
- [x] Acceptance: config parsing, validation, path resolution, and CLI merge pass without audio or keyboard IO.

## v0.3.0 — assets

- [x] Copy source default config to `config/bearilo.toml`. Source: `config/bearilo.toml`.
- [x] Copy source sound files into `assets/sounds/`: `derase.mp3`, `ding.mp3`, `dspark1.mp3`, `dspark2.mp3`, `dspark3.mp3`, `dspark4.mp3`, `dspark5.mp3`, `dspark6.mp3`, `hat.mp3`, `keydown.mp3`, `keystroke.mp3`, `keyup.mp3`, `kick.mp3`, `mbox1.mp3`, `mbox2.mp3`, `mbox3.mp3`, `mbox4.mp3`, `mbox5.mp3`, `mbox6.mp3`, `mbox7.mp3`, `mbox8.mp3`, `mbox9.mp3`, `mbox10.mp3`, `mbox11.mp3`, `newline.mp3`, `quack1.mp3`, `quack2.mp3`, and `snare.mp3`. Source: `sounds/derase.mp3`, `sounds/ding.mp3`, `sounds/dspark1.mp3`, `sounds/dspark2.mp3`, `sounds/dspark3.mp3`, `sounds/dspark4.mp3`, `sounds/dspark5.mp3`, `sounds/dspark6.mp3`, `sounds/hat.mp3`, `sounds/keydown.mp3`, `sounds/keystroke.mp3`, `sounds/keyup.mp3`, `sounds/kick.mp3`, `sounds/mbox1.mp3`, `sounds/mbox2.mp3`, `sounds/mbox3.mp3`, `sounds/mbox4.mp3`, `sounds/mbox5.mp3`, `sounds/mbox6.mp3`, `sounds/mbox7.mp3`, `sounds/mbox8.mp3`, `sounds/mbox9.mp3`, `sounds/mbox10.mp3`, `sounds/mbox11.mp3`, `sounds/newline.mp3`, `sounds/quack1.mp3`, `sounds/quack2.mp3`, `sounds/snare.mp3`.
- [x] Create `src/Bearilo/Assets.hs` with `defaultConfigText :: Text`.
- [x] Create `src/Bearilo/Assets.hs` with `assetManifest :: NonEmpty FilePath`.
- [x] Create `src/Bearilo/Assets.hs` with `lookupEmbeddedSound :: FilePath -> Maybe ByteString`. Source: `crates/daktilo_lib/src/embed.rs`.
- [x] Keep embedded sound lookup by configured file name before external file lookup. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Do not add runtime search paths for embedded sounds because Rust only checks embedded by name and then the configured file path. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test every sound path referenced by `config/bearilo.toml` is present in `assetManifest`. Source: `config/bearilo.toml`, `sounds/`.
- [x] Test `lookupEmbeddedSound "ding.mp3"` returns bytes. Source: `sounds/ding.mp3`.
- [x] Test `lookupEmbeddedSound "missing.mp3"` returns `Nothing`. Source: `crates/daktilo_lib/src/embed.rs`.
- [x] Test `defaultConfigText` parses with `parseConfig`. Source: `crates/daktilo_lib/src/embed.rs`.
- [x] Acceptance: all embedded assets used by default config are found by tests.

## v0.4.0 — audio

- [x] Create `src/Bearilo/Audio/Types.hs` with `Sound`, `SoundChoice`, `PlaybackState`, `AudioError`, and `OutputDeviceName`.
- [x] Create `src/Bearilo/Audio.hs` with `withAudio`, `playSound`, `loadSound`, and `listOutputDevices`.
- [x] Create `src/Bearilo/Audio/SDL.hs` using `sdl2` and `sdl2-mixer`.
- [x] Allocate 8 concurrent playback channels to match Rust sink count. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Implement `listOutputDevices` for output device names. Source: `crates/daktilo_lib/src/audio.rs`, `crates/daktilo/src/main.rs`.
- [x] Implement `loadSound` so embedded sound bytes are tried before file path IO. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Implement volume default `1.0` and configured volume multiplication. Source: `crates/daktilo_lib/src/app.rs`, `README.md`.
- [x] Implement playback-rate variation by resampling decoded PCM before SDL_mixer playback.
- [x] Create pure `chooseRandom :: RandomSeed -> NonEmpty Sound -> (Sound, RandomSeed)` for random playback. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Create pure `soundForEvent :: AppConfig -> KeyEvent -> SoundChoice` for first-match selection. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test missing strategy selects the first configured file. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test random strategy returns an item from the configured non-empty list. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test sequential strategy cycles through configured files. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test variation precedence is CLI, key config, then preset. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Acceptance: audio module compiles with SDL and pure sound mapping tests pass without opening an audio device.
- [ ] Optional: implement pitch-preserving tempo with SoundTouch or another DSP backend.

## v0.5.0 — keyboard input

- [x] Create `src/Bearilo/Os/Types.hs` with `RawKeyEvent`, `RawKeyState`, `RawKeyName`, and `OsHookError`.
- [x] Create `src/Bearilo/Os.hs` with `withKeyListener :: (RawKeyEvent -> IO ()) -> IO a -> IO (Either OsHookError a)`.
- [x] Put Linux FFI imports only in `src/Bearilo/Os/Linux.hs`; matching C files are `bridge/linux.c` and `bridge/linux.h`.
- [x] Put DarwinOS FFI imports only in `src/Bearilo/Os/Darwin.hs`; matching C files are `bridge/darwin.c` and `bridge/darwin.h`.
- [x] Put Windows FFI imports only in `src/Bearilo/Os/Windows.hs`; matching C files are `bridge/windows.c` and `bridge/windows.h`.
- [x] Expose start and stop listener functions only from `bridge/linux.c`, `bridge/darwin.c`, and `bridge/windows.c`.
- [x] Keep C headers limited to `bridge/linux.h`, `bridge/darwin.h`, and `bridge/windows.h`.
- [x] Add Cabal `if os(linux)` section with `c-sources: bridge/linux.c`.
- [x] Add Cabal `if os(darwin)` section with `c-sources: bridge/darwin.c`.
- [x] Add Cabal `if os(windows)` section with `c-sources: bridge/windows.c`.
- [x] Create `src/Bearilo/Input.hs` with `classifyKeyEvent :: RawKeyEvent -> Maybe KeyEvent`. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test raw press converts to app `KeyPressed` and raw release converts to app `KeyReleased`. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Test non-key raw events convert to `Nothing`. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Acceptance: no module except `Bearilo.Os.Linux`, `Bearilo.Os.Darwin`, and `Bearilo.Os.Windows` imports C functions.

## v0.5.1 — real OS keyboard bridge

- [x] Replace Linux bridge placeholder with real keyboard event capture. Prefer evdev-style raw events unless source or platform constraints prove a better backend.
- [x] Replace DarwinOS bridge placeholder with `CGEventTapCreate`-based key press and release capture.
- [x] Replace Windows bridge placeholder with `SetWindowsHookExW` using `WH_KEYBOARD_LL`.
- [x] Add callback plumbing so C bridge events reach the matching `Bearilo.Os.*` module as `RawKeyEvent`.
- [x] Convert platform key codes/names into non-empty `RawKeyName` values through the shared raw event conversion helper.
- [x] Preserve `RawPressed`, `RawReleased`, and `RawOther` mapping without putting key classification in C.
- [x] Keep `Bearilo.App` and `Bearilo.Input` free of FFI imports.
- [x] Return explicit `OsHookError` values for listener start, stop, and callback failures.
- [x] Keep bridge headers limited to start/stop listener API plus the minimum callback type needed for event delivery.
- [x] Add tests for pure platform event conversion where possible without requiring a real global keyboard hook.
- [x] Add manual test notes for Linux, DarwinOS Input Monitoring, and Windows hook startup.
- [ ] Compile-verify `bridge/linux.c` on Linux with Linux input headers and pthread available.
- [ ] Compile-verify `bridge/windows.c` on Windows with `user32` available.
- [ ] Manually verify Linux runtime key events with permission to read `/dev/input/event*`.
- [ ] Manually verify DarwinOS runtime key events with Input Monitoring/Accessibility permission granted to the terminal.
- [ ] Manually verify Windows runtime key events with the low-level hook message loop running.
- [ ] Acceptance: real platform bridges can produce `RawKeyEvent` values through `withKeyListener`, while CI tests do not require global keyboard permissions.

Manual test notes:

- Linux may require root or group permission for `/dev/input/event*`; start `bearilo` from a terminal with permission, press and release a key, and confirm raw key events arrive.
- DarwinOS requires Input Monitoring or Accessibility permission for the terminal application; grant permission, restart the terminal, press and release a key, and confirm raw key events arrive.
- Windows requires the low-level keyboard hook thread to keep its message loop running; start `bearilo`, press and release a key, and confirm raw key events arrive before stopping the listener.

## v0.6.0 — app behaviour parity

- [x] Implement `src/Bearilo/Cli.hs` options matching source flags and env names. Source: `crates/daktilo/src/args.rs`, `README.md`.
- [x] Keep hidden `--no-surprises` in CLI parser. Source: `crates/daktilo/src/args.rs`.
- [x] Implement `App.run` branches for `--init`, `--list-presets`, `--list-devices`, and normal listener mode. Source: `crates/daktilo/src/main.rs`.
- [x] Implement `listPresets` output with preset name plus `Event`, `Keys`, and `File` columns. Source: `crates/daktilo/src/main.rs`.
- [x] Implement default preset `default` when no preset is supplied. Source: `crates/daktilo/src/main.rs`.
- [x] Implement multiple preset playback by creating one app state per selected preset. Source: `crates/daktilo/src/main.rs`, `crates/daktilo_lib/src/lib.rs`.
- [x] Implement disabled-key skip before sound selection. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Implement key regex matching against source key names. Source: `crates/daktilo_lib/src/app.rs`, `README.md`.
- [x] Implement key press suppression until release. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Implement key release playback when a release config matches. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Implement hidden `ak47` preset behaviour and `no_surprises` random-disable behaviour exactly as source. Source: `crates/daktilo_lib/src/config.rs`, `crates/daktilo/src/main.rs`, `README.md`.
- [x] Document `sparks`, not `spark`, because exact preset lookup uses config names and config defines `sparks`. Source: `crates/daktilo_lib/src/config.rs`, `config/bearilo.toml`, `README.md`.
- [x] Add integration tests for `--help`, `--init`, `--list-presets`, missing preset, default preset merge, and explicit config path. Source: `crates/daktilo/src/main.rs`, `crates/daktilo/src/args.rs`.
- [x] Add integration tests for press, repeated press before release, release, disabled key, random strategy, and sequential strategy. Source: `crates/daktilo_lib/src/app.rs`.
- [x] Acceptance: CLI, config, sound choice, and key event behaviour match inspected source except limitations removed in v0.7.0.

> **Limit:** Only remove limitations proven by source files. No guessed cleanup.

## v0.7.0 — limitations removed

- [ ] Split CLI parsing, config loading, command dispatch, and app startup because they are mixed in `crates/daktilo/src/main.rs`.
- [ ] Return `ConfigPathMissing` for an explicit missing config path because fallback to embedded config is used for any missing selected path in `crates/daktilo/src/main.rs`.
- [ ] Move key classification into pure `Bearilo.Input.classifyKeyEvent` because keyboard event handling and sound playback are mixed in `crates/daktilo_lib/src/app.rs`.
- [ ] Move random sound selection into pure `Bearilo.Audio.chooseSound` because `fastrand` is called inside `crates/daktilo_lib/src/app.rs`.
- [ ] Move variation factor generation into pure `Bearilo.Audio.applyVariation` because random variation is generated inside `crates/daktilo_lib/src/app.rs`.
- [ ] Store sequential playback index per key config because one `file_index` is shared across all key configs in `crates/daktilo_lib/src/app.rs`.
- [ ] Lowercase both requested and available output device names because only available names are lowercased in `crates/daktilo_lib/src/app.rs`.
- [ ] Return `OsHookError` from listener startup because `expect("could not listen events")` can panic inside `crates/daktilo_lib/src/lib.rs`.
- [ ] Add embedded sound manifest tests because only embedded config parse is tested in `crates/daktilo_lib/src/embed.rs`.
- [ ] Replace stale audio feature tests because `crates/daktilo_lib/src/app.rs` tests call old fields and old `App::init` shape.
- [ ] Fix preset docs to use `sparks` because README lists `spark` while `config/bearilo.toml` defines `sparks`.
- [ ] Test each removed limitation with a focused Hspec example in `test/LimitationSpec.hs`.
- [ ] Acceptance: every limitation listed in `## Original daktilo limitations` has a failing regression test before the fix and a passing test after the fix.

## v0.8.0 — packaging

- [ ] Wire `bearilo.cabal` executable, library, and test suite so `cabal build all` works.
- [ ] Add `cabal install exe:bearilo` to `README.md`.
- [ ] Add Linux runtime dependency notes for `alsa-lib libxtst libxi`, `alsa-lib-dev libxi-dev libxtst-dev`, and `libasound2-dev libxi-dev libxtst-dev`. Source: `README.md`, `crates/daktilo/Cargo.toml`.
- [ ] Add DarwinOS Input Monitoring note to `README.md`. Source: `README.md`.
- [ ] Add Windows note that source lists Windows support and no extra permission step was found. Source: `README.md`.
- [ ] Keep Cabal `c-sources` OS sections limited to the matching file in `bridge/`.
- [ ] Add Cabal include settings for `bridge/linux.h`, `bridge/Darwin.h`, and `bridge/windows.h`.
- [ ] Do not clone cargo-dist metadata because it only defines Rust release installers and targets. Source: `Cargo.toml`.
- [ ] Do not clone WiX XML unless Cabal packaging gains an MSI task. Source: `crates/daktilo/wix/main.wxs`.
- [ ] Add `test/PackagingSpec.hs` to check `bridge/` filenames and Cabal C source entries.
- [ ] Acceptance: package builds, installs locally, and contains only the three OS C source files selected by Cabal conditionals.

## v1.0.0 — release

- [ ] Run manual test `cabal run bearilo -- --help`. Source: `README.md`, `crates/daktilo/src/args.rs`.
- [ ] Run manual test `cabal run bearilo -- --init` and verify `bearilo.toml` is written. Source: `crates/daktilo/src/main.rs`.
- [ ] Run manual test `cabal run bearilo -- --list-presets`. Source: `crates/daktilo/src/main.rs`.
- [ ] Run manual test `cabal run bearilo -- --list-devices`. Source: `crates/daktilo/src/main.rs`, `crates/daktilo_lib/src/audio.rs`.
- [ ] Run manual test for `default`, `basic`, `musicbox`, `ducktilo`, `drumkit`, and `sparks`. Source: `config/bearilo.toml`.
- [ ] Run manual test for `--config <PATH>` with valid config and invalid config. Source: `README.md`, `crates/daktilo_lib/src/config.rs`.
- [ ] Run manual test for `--variate-volume` and `--variate-tempo` with one value and two values. Source: `crates/daktilo/src/args.rs`.
- [ ] Run manual test for `--no-surprises` and `--preset ak47`. Source: `crates/daktilo/src/args.rs`, `crates/daktilo_lib/src/config.rs`.
- [ ] Update `README.md` with only implemented CLI options, config fields, presets, platform notes, and install steps.
- [ ] Add `examples/bearilo.toml` copied from implemented default config.
- [ ] Add final parity checklist to `README.md` for CLI, config, assets, audio, keyboard input, and errors.
- [ ] Add release notes that list source-compatible behaviour and limitations removed.
- [ ] Acceptance: `cabal build`, `cabal test`, manual tests, README checks, and platform notes are complete.

## Original daktilo limitations

| Limitation                                                                 | Evidence                           | Bearilo fix                                                                |
| -------------------------------------------------------------------------- | ---------------------------------- | -------------------------------------------------------------------------- |
| Config loading, CLI dispatch, listing commands, and app startup are mixed. | `crates/daktilo/src/main.rs`       | Split into `Bearilo.Cli`, `Bearilo.Config`, and `Bearilo.App`.             |
| Explicit missing config path is hidden by fallback to embedded config.     | `crates/daktilo/src/main.rs`       | Return `ConfigPathMissing FilePath`.                                       |
| Keyboard event handling and sound playback are mixed.                      | `crates/daktilo_lib/src/app.rs`    | Put classification in `Bearilo.Input` and playback behind `Bearilo.Audio`. |
| Random sound choice is hidden inside IO app state.                         | `crates/daktilo_lib/src/app.rs`    | Use pure `Bearilo.Audio.chooseSound`.                                      |
| Random variation is hidden inside IO app state.                            | `crates/daktilo_lib/src/app.rs`    | Use pure `Bearilo.Audio.applyVariation`.                                   |
| Sequential playback state is shared across all key configs.                | `crates/daktilo_lib/src/app.rs`    | Store sequential index per key config.                                     |
| Device lookup lowercases only available device names.                      | `crates/daktilo_lib/src/app.rs`    | Lowercase requested and available output device names.                     |
| Listener startup can panic.                                                | `crates/daktilo_lib/src/lib.rs`    | Return `OsHookError` from listener startup.                                |
| Embedded sounds are not checked by tests.                                  | `crates/daktilo_lib/src/embed.rs`  | Add embedded sound manifest tests.                                         |
| Feature-gated audio tests are stale.                                       | `crates/daktilo_lib/src/app.rs`    | Replace with current pure and integration tests.                           |
| README preset table names `spark`, but config defines `sparks`.            | `README.md`, `config/bearilo.toml` | Document and test `sparks`.                                                |

## Haskell design rules

| Boundary          | Rule                                                                                                                             |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Main              | Keep `app/Main.hs` as only `main = App.run`.                                                                                     |
| Runtime modules   | Put all runtime behaviour under `src/Bearilo`.                                                                                   |
| CLI               | Keep CLI parsing in `Bearilo.Cli`.                                                                                               |
| Config            | Keep config parsing and validation in `Bearilo.Config`.                                                                          |
| Assets            | Keep embedded asset lookup in `Bearilo.Assets`.                                                                                  |
| Audio             | Keep audio effects behind `Bearilo.Audio`.                                                                                       |
| OS keyboard       | Keep OS keyboard hooks behind `Bearilo.Os`.                                                                                      |
| OS types          | Keep shared OS types in `Bearilo.Os.Types`.                                                                                      |
| Linux OS files    | Keep Linux Haskell FFI in `src/Bearilo/Os/Linux.hs`; keep C in `bridge/linux.c` and `bridge/linux.h`.                            |
| DarwinOS OS files | Keep DarwinOS Haskell FFI in `src/Bearilo/Os/Darwin.hs`; keep C in `bridge/Darwin.c` and `bridge/Darwin.h`.                      |
| Windows OS files  | Keep Windows Haskell FFI in `src/Bearilo/Os/Windows.hs`; keep C in `bridge/windows.c` and `bridge/windows.h`.                    |
| C files           | Keep C files only in `bridge/`.                                                                                                  |
| C filenames       | Do not put `bridge` in filenames inside `bridge/`.                                                                               |
| CPP               | Keep CPP conditionals only in `Bearilo.Os` and `bearilo.cabal`.                                                                  |
| FFI               | Use Haskell FFI for C calls with `default-language: GHC2021`.                                                                    |
| C callbacks       | Convert C callbacks into `Bearilo.Os.Types.RawKeyEvent` inside the matching OS module.                                           |
| C scope           | Keep sound playback, config parsing, random sound selection, and app logic out of C.                                             |
| C imports         | Do not import C functions from `Bearilo.App` or `Bearilo.Input`.                                                                 |
| Pure functions    | Keep `parseConfig`, `mergeConfig`, `classifyKeyEvent`, `soundForEvent`, `chooseSound`, `validateConfig`, and `renderError` pure. |
| Errors            | Use `Either` or `ExceptT` for recoverable errors.                                                                                |
| State             | Use STM or `MVar` only at IO boundaries.                                                                                         |
| Globals           | Avoid global mutable state.                                                                                                      |
| Partial functions | Avoid partial functions.                                                                                                         |
| Config types      | Avoid stringly typed config after `validateConfig`.                                                                              |
| ADTs              | Use small ADTs for config, key events, audio choices, and errors.                                                                |
| Dependencies      | Add dependencies only when a checklist item names the module that uses them.                                                     |

| Dependency                       | Used in                                                                      | Replaces               |
| -------------------------------- | ---------------------------------------------------------------------------- | ---------------------- |
| `optparse-applicative`           | `Bearilo.Cli`                                                                | `clap`                 |
| `directory`                      | `Bearilo.Config`                                                             | `dirs`                 |
| `xdg-basedir`                    | `Bearilo.Config`                                                             | `dirs`                 |
| `regex-tdfa`                     | `Bearilo.Config`                                                             | `regex`, `serde_regex` |
| `toml-parser`                    | `Bearilo.Config`                                                             | `serde`, `toml`        |
| `file-embed`                     | `Bearilo.Assets`                                                             | `rust-embed`           |
| `sdl2`                           | `Bearilo.Audio.SDL`                                                          | `rodio`                |
| `sdl2-mixer`                     | `Bearilo.Audio.SDL`                                                          | `rodio`                |
| `Bearilo.Os` plus `bridge/*.c`   | `Bearilo.Os.*`                                                               | `rdev`                 |
| Custom error ADTs                | `Bearilo.Error`, `Bearilo.Config`, `Bearilo.Audio.Types`, `Bearilo.Os.Types` | `thiserror`            |
| Simple logging                   | `Bearilo.App`                                                                | `tracing`              |
| `hspec`                          | `test/`                                                                      | `pretty_assertions`    |
| `hspec-expectations-pretty-diff` | `test/`                                                                      | `pretty_assertions`    |

## Things not to port

> **Do not:** Do not clone Rust release Darwinhinery unless it changes runtime behaviour.

| Do not port                             | Replacement / reason                                                   | Source                                                                     |
| --------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Rust two-crate layout                   | Bearilo has one library and one executable.                            | `Cargo.toml`, `crates/daktilo/Cargo.toml`, `crates/daktilo_lib/Cargo.toml` |
| `crates/daktilo/src/bin/completions.rs` | It generates shell completion files.                                   | `crates/daktilo/src/bin/completions.rs`                                    |
| `crates/daktilo/src/bin/mangen.rs`      | It generates a man page.                                               | `crates/daktilo/src/bin/mangen.rs`                                         |
| cargo-dist installer metadata           | It defines Rust release installers and targets, not runtime behaviour. | `Cargo.toml`                                                               |
| WiX XML                                 | It is installer metadata, not runtime behaviour.                       | `crates/daktilo/wix/main.wxs`                                              |
| `rdev`                                  | Replace with `Bearilo.Os` plus `bridge/*.c`.                           | `crates/daktilo_lib/Cargo.toml`, `crates/daktilo_lib/src/lib.rs`           |
| `rodio`                                 | Replace with `sdl2` and `sdl2-mixer`.                                  | `crates/daktilo_lib/Cargo.toml`, `crates/daktilo_lib/src/app.rs`           |
| `rust-embed`                            | Replace with `file-embed`.                                             | `crates/daktilo_lib/Cargo.toml`, `crates/daktilo_lib/src/embed.rs`         |
| `thiserror`                             | Use `AppError`, `ConfigError`, `AudioError`, and `OsHookError`.        | `crates/daktilo_lib/src/error.rs`                                          |
| Stale `audio-tests` code                | Replace with current pure and integration tests.                       | `crates/daktilo_lib/src/app.rs`                                            |

## Final acceptance checklist

> **Note:** These checks must pass before calling the rewrite usable.

- [ ] `cabal build` passes.
- [ ] `cabal test` passes.
- [ ] `cabal run bearilo -- --help` works.
- [ ] `app/Main.hs` only calls `App.run`.
- [ ] `Bearilo.Os` is the only public OS keyboard boundary.
- [ ] `bridge/` contains only `linux.c`, `linux.h`, `Darwin.c`, `Darwin.h`, `windows.c`, `windows.h`.
- [ ] No file inside `bridge/` contains `bridge` in its filename.
- [ ] No app module imports C functions directly.
- [ ] Default config works.
- [ ] User config path works.
- [ ] Embedded sounds are found.
- [ ] Key press plays the expected sound.
- [ ] Key release behaviour matches source.
- [ ] Missing or invalid config gives a specific error.
- [ ] Linux backend works or is explicitly marked incomplete.
- [ ] DarwinOS backend works or is explicitly marked incomplete.
- [ ] Windows backend works or is explicitly marked incomplete.
- [ ] README describes only implemented behaviour.
