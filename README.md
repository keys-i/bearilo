# Bearilo

Bearilo is a small Haskell desktop utility that turns global keyboard input
into short typewriter-inspired sounds.

## Build, test, and run

```sh
cabal build all
cabal test all
cabal install exe:bearilo
cabal run bearilo -- --help
```

## CLI

Implemented options:

- `-h`, `--help`
- `-v`, `--version`
- `--init`
- `--list-presets`
- `--list-devices`
- `-V`, `--verbose`
- `--preset PRESET`
- `--device DEVICE`
- `--config PATH`
- `--variate-volume VALUE`
- `--variate-tempo VALUE`

`--no-surprises` is implemented as a hidden option.

For two-value variation ranges, pass the option twice:

```sh
cabal run bearilo -- --variate-volume 0.1 --variate-volume 0.2
cabal run bearilo -- --variate-tempo 0.05 --variate-tempo 0.1
```

## Config

`--init` writes `bearilo.toml` in the current directory.

Without `--config`, Bearilo looks for config files in this order:

- `$XDG_CONFIG_HOME/bearilo.toml`
- `$XDG_CONFIG_HOME/daktilo/bearilo.toml`
- `$XDG_CONFIG_HOME/daktilo/config`

If no config file is found, Bearilo uses the embedded default config from
`examples/bearilo.toml`.

Implemented config fields:

- top-level `no_surprises`
- `[[sound_preset]]`
- preset `name`
- preset `key_config`
- preset `disabled_keys`
- preset `variation`
- key config `event`
- key config `keys`
- key config `files`
- key config `strategy`
- key config `variation`
- file `path`
- file `volume`
- variation `volume`
- variation `tempo`

Implemented `event` values are `press` and `release`.

Implemented `strategy` values are `random` and `sequential`.

Variation ranges accept one or two numeric values.

## Presets

Built-in presets:

- `default`
- `basic`
- `musicbox`
- `ducktilo`
- `drumkit`
- `sparks`

The hidden `ak47` preset is available by explicit preset selection.

## Platform notes

### Linux

Linux may need permission to read input devices.

Runtime packages on Arch:

```sh
alsa-lib libxtst libxi
```

Development packages when building from source on Alpine-style systems:

```sh
alsa-lib-dev libxi-dev libxtst-dev
```

Development packages when building from source on Debian/Ubuntu-style systems:

```sh
libasound2-dev libxi-dev libxtst-dev
```

### DarwinOS/macOS

DarwinOS/macOS requires Input Monitoring permission for global keyboard
monitoring. Bearilo requests the normal event-listening permission prompt when
the listener starts.

If macOS still blocks the listener, grant the terminal or app that starts
Bearilo in System Settings > Privacy & Security > Input Monitoring, then quit
and reopen that terminal or app.

### Windows

Windows support is implemented in source through the Windows keyboard bridge and
Cabal `os(windows)` wiring. Verify on Windows before release.

## Manual release checklist

- [ ] `cabal run bearilo -- --help`
- [ ] `cabal run bearilo -- --init`
- [ ] Verify `bearilo.toml` is written by `--init`.
- [ ] `cabal run bearilo -- --list-presets`
- [ ] `cabal run bearilo -- --list-devices`
- [ ] Run with `--preset default`.
- [ ] Run with `--preset basic`.
- [ ] Run with `--preset musicbox`.
- [ ] Run with `--preset ducktilo`.
- [ ] Run with `--preset drumkit`.
- [ ] Run with `--preset sparks`.
- [ ] Run `--config <PATH>` with a valid config.
- [ ] Run `--config <PATH>` with an invalid config.
- [ ] Verify an explicit missing config path reports the missing-path error before release.
- [ ] Run with `--variate-volume <ONE>`.
- [ ] Run with `--variate-volume <LOW> --variate-volume <HIGH>`.
- [ ] Run with `--variate-tempo <ONE>`.
- [ ] Run with `--variate-tempo <LOW> --variate-tempo <HIGH>`.
- [ ] Run with `--no-surprises`.
- [ ] Run with `--preset ak47`.

## Final parity checklist

- [ ] CLI
- [ ] config loading
- [ ] default config
- [ ] preset listing
- [ ] preset selection
- [ ] embedded assets
- [ ] audio playback
- [ ] variation
- [ ] keyboard input
- [ ] disabled keys
- [ ] press suppression
- [ ] release playback
- [ ] errors
- [ ] packaging
- [ ] platform notes

## Release notes

Source-compatible behaviours kept:

- CLI flags and environment variable names remain compatible with the inspected source.
- `--init` writes `bearilo.toml`.
- Built-in preset names are `default`, `basic`, `musicbox`, `ducktilo`, `drumkit`, and `sparks`.
- Config loading keeps the implemented search order and embedded default fallback.
- Embedded sound lookup tries bundled assets by configured file name before file path loading.
- Key matching uses configured regex strings.
- Press and release events are handled separately.
- `ak47` remains available as a hidden preset.

Limitations removed:

- CLI parsing, config loading, command dispatch, and runtime startup are split into separate modules.
- Key classification is pure and outside the OS bridge.
- Random sound choice and variation logic are testable outside audio hardware.
- Sequential playback state is tracked per key config.
- Output device lookup is case-insensitive for requested and available names.
- Listener startup can return an `OsHookError`.
- Embedded config sound references are covered by tests.

Unsupported or deferred:

- No installer support is documented.
- No Homebrew support is documented.
- No MSI support is documented.
- No cargo-dist release support is documented.
- Wayland runtime behaviour is not claimed.
- Pitch-preserving tempo processing remains deferred.
- Platform runtime verification still needs to be completed on release targets.

Manual test summary:

- Run the Cabal build, test, install, and help commands.
- Verify init, preset listing, device listing, each built-in preset, config handling, variation flags, and hidden surprise options.
- Verify Linux input permissions, DarwinOS/macOS Input Monitoring, and Windows runtime behaviour on the target platform.

## Final acceptance checklist

- [ ] `cabal build all`
- [ ] `cabal test all`
- [ ] README release checklist completed.
- [ ] Manual release checklist completed.
- [ ] Platform notes verified on release targets.
- [ ] No unsupported installer or distribution claim is present.
