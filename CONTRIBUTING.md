# Contributing

Thanks for wanting to help with **Bearilo**.

Bearilo is a Haskell/Cabal app for keyboard sounds while typing. The code should
stay small, testable, and as functionally pure as the operating system allows.

`λʕ•ᴥ•ʔλ powered by bears, checked by types.`

## Quick links

- [Code of Conduct](#code-of-conduct)
- [Code style](#code-style)
- [Getting started](#getting-started)
- [Issues](#issues)
- [Pull requests](#pull-requests)
- [Functional purity rules](#functional-purity-rules)
- [Functional purity score](#functional-purity-score)
- [How to add new presets](#how-to-add-new-presets)
- [OS bridge changes](#os-bridge-changes)
- [Tests](#tests)
- [HLint](#hlint)
- [Before opening a PR](#before-opening-a-pr)
- [License](#license)

## Code of Conduct

Please follow the [Code of Conduct](./CODE_OF_CONDUCT.md).

Short version: be kind, be specific, and keep the bear cave pleasant.

## Getting started

```sh
git clone https://github.com/<user>/bearilo
cd bearilo
cabal update
cabal build all
cabal test all
```

Useful local commands:

```sh
cabal run exe:bearilo -- --help
cabal run exe:bearilo -- --list-presets
```

Do not add CI tests that require keyboard permissions or audio hardware. Normal
listener mode touches OS hooks and may need Input Monitoring or input-device
permissions.

## Issues

Good issues are short and reproducible.

Please include:

- OS
- terminal
- GHC version
- Cabal version
- command run
- expected behaviour
- actual behaviour
- relevant logs with `-V` or `-VV`
- whether Input Monitoring or input-device permissions were granted

## Pull requests

- One concern per PR.
- Keep changed lines low.
- Add tests for behaviour changes.
- Update README/config examples if user-facing behaviour changes.
- Do not mix formatting-only changes with logic changes.
- Do not touch `bridge/` unless working on OS hooks.
- Do not add dependencies casually.
- Explain why a new dependency is needed.

Small PRs are easier to review and less likely to step on a sleeping bear.

## Functional purity rules

This part matters.

- Keep IO at the edges.
- Keep pure decisions pure.
- Put CLI parsing in `Bearilo.Cli`.
- Put config parsing/validation in `Bearilo.Config`.
- Put key classification in `Bearilo.Input`.
- Put sound selection in `Bearilo.Audio`.
- Put OS hooks in `Bearilo.Os`.
- Put C-only platform glue in `bridge/`.
- Do not import FFI from app logic.
- Do not put app logic in C.
- Do not put sound playback in C.
- Do not hide randomness in IO-heavy code.
- Thread seeds through pure functions where practical.
- Use explicit errors instead of silent fallback.
- Use `Either` and small ADTs where useful.
- Avoid global mutable state.
- Avoid partial functions.
- Keep renderers pure.
- Keep tests hardware-free where possible.

Good:

```haskell
chooseSound :: RandomSeed -> NonEmpty Sound -> (Sound, RandomSeed)
```

Bad:

```haskell
chooseSound :: [Sound] -> IO Sound
```

The first one is boring to test. That is the point.

## Functional purity score

The README badge is a deterministic heuristic. It rewards pure logic and tests,
and penalises IO leakage, FFI leakage, partial functions, suspicious bridge C
words, and HLint hints.

Formula:

```text
score = clamp(0, 100, 100 - ioPenalty - ffiPenalty - partialPenalty - cPenalty - hlintPenalty + testReward)
```

It is not a moral judgement from the bears. The exact formula and scanner live
in `scripts/functional-purity-score.py`.

## Code style

- Prefer boring readable Haskell.
- Avoid clever point-free code.
- Avoid giant functions.
- Collapse one-use helpers into `where`.
- Keep helpers top-level if reused, exported, tested, or clearer.
- Keep exported functions documented with short Haddock.
- Comments should explain weird behaviour, not obvious code.
- Use casual Haddock docs, not corporate docs.

Good Haddock:

```haskell
-- | Pick the next sound without touching IO.
chooseSound :: RandomSeed -> NonEmpty Sound -> (Sound, RandomSeed)
```

Bad Haddock:

```haskell
-- | Leverages a robust scalable audio selection pipeline.
```

## How to add new presets

1. Add or reuse sound files under `assets/sounds/`.
2. Add the preset to the default config file currently used by the repo.
3. Make sure every referenced sound exists in the embedded asset manifest.
4. Add the preset to README.
5. Add or update tests for preset listing.
6. Run:

```sh
cabal test all
cabal run exe:bearilo -- --list-presets
```

Notes:

- MP3 is the supported sound format currently used by the repo.
- Do not reference missing files.
- Use `sparks`, not `spark`.
- Keep preset names lowercase unless there is a reason.

## OS bridge changes

The OS bridge files are:

- `bridge/linux.c`
- `bridge/darwin.c`
- `bridge/windows.c`

Rules:

- Do not rename bridge files.
- Do not put `bridge` in filenames inside `bridge/`.
- Keep the C API small.
- Convert platform events into raw events.
- Keep app-level key matching in Haskell.
- Add manual test notes for OS-specific changes.

## Tests

Run:

```sh
cabal test all
```

If a test shape repeats, prefer parameterised or table-driven tests. Do not copy
the same test ten times with tiny edits.

Good test areas:

- CLI parsing tests
- config parser tests
- key normalisation tests
- sound selection tests
- renderer tests
- asset manifest tests

Keep hardware tests manual. CI tests must not require keyboard permissions or
audio hardware.

## HLint

Run:

```sh
hlint app src test
```

Optional report:

```sh
hlint app src test --report
```

HLint suggestions are useful, not holy scripture. Do not accept suggestions that
make code harder to read. If ignoring a hint, keep the reason simple.

## Before opening a PR

- `cabal build all`
- `cabal test all`
- `hlint app src test`
- `cabal run exe:bearilo -- --help`
- `cabal run exe:bearilo -- --list-presets`
- README updated if user-facing behaviour changed
- CHANGELOG updated if release-facing behaviour changed
- no unrelated formatting churn
- no unsupported feature claims

## License

By contributing, you agree that your contributions are licensed under the same
license terms as Bearilo. See [LICENSE](./LICENSE).
