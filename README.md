# Bearilo

Bearilo is a small Haskell desktop utility that turns global keyboard input
into short typewriter-inspired sounds.

## Build, Test, And Run

Build every enabled Cabal component:

```sh
cabal build all
```

Run the test suite:

```sh
cabal test all
```

Run Bearilo locally:

```sh
cabal run exe:bearilo -- --help
```

Install the executable locally:

```sh
cabal install exe:bearilo
```

## Presets

Built-in presets:

- `default`
- `basic`
- `musicbox`
- `ducktilo`
- `drumkit`
- `sparks`

## Platform Notes

### Linux

Runtime packages on Arch:

```sh
alsa-lib libxtst libxi
```

Development packages when building from source on Alpine-style systems:

```sh
alsa-lib-dev libxi-dev libxtst-dev
```

Development packages when building from source on Debian-style systems:

```sh
libasound2-dev libxi-dev libxtst-dev
```

### DarwinOS/macOS

Input Monitoring permission is required for apps that monitor keyboard, mouse,
or trackpad input.

Grant it in System Settings > Privacy & Security > Input Monitoring.

### Windows

The inspected source lists Windows support. No extra permission step was found
in the inspected source.
