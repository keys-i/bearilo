#!/usr/bin/env python3
"""Compute Bearilo's functional purity score.

Formula:
score = clamp(0, 100, 100 - ioPenalty - ffiPenalty - partialPenalty - cPenalty - hlintPenalty + testReward)
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


FORMULA = "score = clamp(0, 100, 100 - ioPenalty - ffiPenalty - partialPenalty - cPenalty - hlintPenalty + testReward)"

EXPECTED_IO_MODULES = {
    "Bearilo.App",
    "Bearilo.Audio",
    "Bearilo.Audio.SDL",
    "Bearilo.Os",
    "Bearilo.Os.Linux",
    "Bearilo.Os.Darwin",
    "Bearilo.Os.Windows",
    "Bearilo.Cli",
    "Bearilo.Config",
    "Bearilo.Logger",
    "Bearilo.Output",
}

ALLOWED_FFI_FILES = {
    "src/Bearilo/Os/Linux.hs",
    "src/Bearilo/Os/Darwin.hs",
    "src/Bearilo/Os/Windows.hs",
}

PARTIAL_FUNCTIONS = [
    "head",
    "tail",
    "last",
    "init",
    "fromJust",
    "read",
    "error",
    "undefined",
    "unsafePerformIO",
]

C_SUSPICIOUS_WORDS = [
    "play",
    "sound",
    "config",
    "preset",
    "volume",
    "tempo",
]


@dataclass(frozen=True)
class RepoFiles:
    src: dict[str, str]
    tests: dict[str, str]
    bridge_c: dict[str, str]
    app: dict[str, str]


@dataclass(frozen=True)
class HlintResult:
    available: bool
    hints: int
    warning: str | None


@dataclass(frozen=True)
class ScoreResult:
    score: int
    color: str
    penalties: dict[str, int]
    raw_counts: dict[str, int]
    test_reward: int
    test_reward_items: dict[str, bool]
    hlint: HlintResult
    files_scanned: dict[str, list[str]]
    warnings: list[str]


def read_repository_files(src: Path, tests: Path, bridge: Path, app: Path) -> RepoFiles:
    """Read the files used by the score."""
    return RepoFiles(
        src=read_files(src, "*.hs"),
        tests=read_files(tests, "*.hs"),
        bridge_c=read_files(bridge, "*.c"),
        app=read_files(app, "*.hs") if app.exists() else {},
    )


def read_files(root: Path, pattern: str) -> dict[str, str]:
    if not root.exists():
        return {}

    files: dict[str, str] = {}
    for path in sorted(root.rglob(pattern)):
        if path.is_file():
            files[posix_path(path)] = path.read_text(encoding="utf-8", errors="replace")
    return files


def compute_score(files: RepoFiles, hlint: HlintResult) -> ScoreResult:
    io_leaks = find_io_leaks(files.src)
    ffi_leaks = find_ffi_leaks(files.src)
    partials = find_partial_functions(files.src)
    c_matches = find_c_suspicious_matches(files.bridge_c)
    reward_items = find_test_reward_items(files.tests)

    io_penalty = min(len(io_leaks) * 4, 20)
    ffi_penalty = min(len(ffi_leaks) * 15, 30)
    partial_penalty = min(sum(partials.values()) * 2, 20)
    c_penalty = min(sum(c_matches.values()) * 5, 20)
    hlint_penalty = min(hlint.hints, 15) if hlint.available else 0
    test_reward = min(sum(5 for covered in reward_items.values() if covered), 25)

    score = clamp(
        0,
        100,
        100 - io_penalty - ffi_penalty - partial_penalty - c_penalty - hlint_penalty + test_reward,
    )

    warnings = [
        "Partial-function scanning ignores comments and strings, but it is still lexical.",
        "Bridge C scanning is a word heuristic, not proof of app logic in C.",
    ]
    if hlint.warning:
        warnings.append(hlint.warning)

    return ScoreResult(
        score=score,
        color=color_for_score(score),
        penalties={
            "ioPenalty": io_penalty,
            "ffiPenalty": ffi_penalty,
            "partialPenalty": partial_penalty,
            "cPenalty": c_penalty,
            "hlintPenalty": hlint_penalty,
        },
        raw_counts={
            "ioLeakSignatures": len(io_leaks),
            "ffiLeakImports": len(ffi_leaks),
            "partialFunctionOccurrences": sum(partials.values()),
            "cSuspiciousMatches": sum(c_matches.values()),
            "hlintHints": hlint.hints,
        },
        test_reward=test_reward,
        test_reward_items=reward_items,
        hlint=hlint,
        files_scanned={
            "src": sorted(files.src.keys()),
            "tests": sorted(files.tests.keys()),
            "bridge_c": sorted(files.bridge_c.keys()),
            "app": sorted(files.app.keys()),
        },
        warnings=warnings,
    )


def find_io_leaks(src_files: dict[str, str]) -> list[str]:
    leaks: list[str] = []
    for path, text in src_files.items():
        module_name = module_name_from_text(text) or module_name_from_path(path)
        if module_name in EXPECTED_IO_MODULES:
            continue

        stripped = strip_haskell_comments_and_strings(text)
        for line_number, signature in type_signatures(stripped):
            if re.search(r"\bIO\b", signature):
                leaks.append(f"{path}:{line_number}")
    return leaks


def find_ffi_leaks(src_files: dict[str, str]) -> list[str]:
    leaks: list[str] = []
    for path, text in src_files.items():
        if path in ALLOWED_FFI_FILES:
            continue

        stripped = strip_haskell_comments_and_strings(text)
        leaks.extend(f"{path}:{line_number}" for line_number, line in numbered_lines(stripped) if "foreign import" in line)
    return leaks


def find_partial_functions(src_files: dict[str, str]) -> dict[str, int]:
    counts = {name: 0 for name in PARTIAL_FUNCTIONS}
    counts["!!"] = 0

    for text in src_files.values():
        stripped = strip_haskell_comments_and_strings(text)
        counts["!!"] += stripped.count("!!")
        for name in PARTIAL_FUNCTIONS:
            counts[name] += len(re.findall(rf"(?<![.\w']){re.escape(name)}(?![\w'])", stripped))

    return {name: count for name, count in counts.items() if count > 0}


def find_c_suspicious_matches(bridge_files: dict[str, str]) -> dict[str, int]:
    counts = {word: 0 for word in C_SUSPICIOUS_WORDS}
    for text in bridge_files.values():
        stripped = strip_c_comments_and_strings(text).lower()
        for word in C_SUSPICIOUS_WORDS:
            counts[word] += len(re.findall(rf"\b{re.escape(word)}\b", stripped))
    return {word: count for word, count in counts.items() if count > 0}


def find_test_reward_items(test_files: dict[str, str]) -> dict[str, bool]:
    tests = "\n".join(test_files.values())
    return {
        "classifyKeyEvent": "classifyKeyEvent" in tests,
        "randomSoundSelection": any(name in tests for name in ["chooseSound", "chooseRandom"]),
        "configParsingValidation": any(name in tests for name in ["parseConfig", "validateConfig"]),
        "presetRenderingListing": any(name in tests for name in ["listPresets", "renderPresetList"]),
        "logRendering": "renderLogLine" in tests,
    }


def run_hlint(app: Path, src: Path, tests: Path) -> HlintResult:
    hlint = shutil.which("hlint")
    if hlint is None:
        return HlintResult(False, 0, "HLint was not available; no HLint penalty applied.")

    paths = [path for path in [app, src, tests] if path.exists()]
    if not paths:
        return HlintResult(True, 0, "HLint was available, but no HLint paths existed.")

    json_result = subprocess.run(
        [hlint, "--json", *map(str, paths)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

    try:
        hints = json.loads(json_result.stdout or "[]")
        if isinstance(hints, list):
            return HlintResult(True, len(hints), None)
    except json.JSONDecodeError:
        pass

    plain_result = subprocess.run(
        [hlint, *map(str, paths)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    output = plain_result.stdout + "\n" + plain_result.stderr
    if "No hints" in output:
        return HlintResult(True, 0, None)

    hint_count = len(re.findall(r"^[^:\n]+:\d+:\d+", output, flags=re.MULTILINE))
    warning = None if hint_count else "HLint ran, but its output could not be counted confidently."
    return HlintResult(True, hint_count, warning)


def type_signatures(text: str) -> list[tuple[int, str]]:
    lines = text.splitlines()
    signatures: list[tuple[int, str]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if "::" not in line:
            index += 1
            continue

        start_line = index + 1
        block = [line]
        next_index = index + 1
        while next_index < len(lines):
            next_line = lines[next_index]
            if next_line.startswith(" ") or next_line.strip().startswith(("->", "=>")):
                block.append(next_line)
                next_index += 1
                continue
            break

        signatures.append((start_line, "\n".join(block)))
        index = max(next_index, index + 1)
    return signatures


def strip_haskell_comments_and_strings(text: str) -> str:
    result: list[str] = []
    index = 0
    block_depth = 0
    in_string = False
    escaped = False

    while index < len(text):
        char = text[index]
        pair = text[index : index + 2]

        if block_depth:
            if pair == "{-":
                block_depth += 1
                result.extend("  ")
                index += 2
            elif pair == "-}":
                block_depth -= 1
                result.extend("  ")
                index += 2
            else:
                result.append("\n" if char == "\n" else " ")
                index += 1
            continue

        if in_string:
            result.append("\n" if char == "\n" else " ")
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if pair == "--":
            while index < len(text) and text[index] != "\n":
                result.append(" ")
                index += 1
            continue

        if pair == "{-":
            block_depth = 1
            result.extend("  ")
            index += 2
            continue

        if char == '"':
            in_string = True
            result.append(" ")
            index += 1
            continue

        result.append(char)
        index += 1

    return "".join(result)


def strip_c_comments_and_strings(text: str) -> str:
    result: list[str] = []
    index = 0
    in_block = False
    in_line = False
    in_string = False
    in_char = False
    escaped = False

    while index < len(text):
        char = text[index]
        pair = text[index : index + 2]

        if in_line:
            if char == "\n":
                in_line = False
                result.append(char)
            else:
                result.append(" ")
            index += 1
            continue

        if in_block:
            if pair == "*/":
                in_block = False
                result.extend("  ")
                index += 2
            else:
                result.append("\n" if char == "\n" else " ")
                index += 1
            continue

        if in_string or in_char:
            result.append("\n" if char == "\n" else " ")
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif in_string and char == '"':
                in_string = False
            elif in_char and char == "'":
                in_char = False
            index += 1
            continue

        if pair == "//":
            in_line = True
            result.extend("  ")
            index += 2
            continue

        if pair == "/*":
            in_block = True
            result.extend("  ")
            index += 2
            continue

        if char == '"':
            in_string = True
            result.append(" ")
            index += 1
            continue

        if char == "'":
            in_char = True
            result.append(" ")
            index += 1
            continue

        result.append(char)
        index += 1

    return "".join(result)


def write_outputs(out: Path, report: Path, result: ScoreResult) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(badge_payload(result), indent=2) + "\n", encoding="utf-8")
    report.write_text(render_report(result), encoding="utf-8")


def badge_payload(result: ScoreResult) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "label": "functional purity",
        "message": f"{result.score}%",
        "color": result.color,
        "score": result.score,
        "max": 100,
        "formula": FORMULA,
        "penalties": result.penalties,
        "rewards": {"testReward": result.test_reward, "items": result.test_reward_items},
        "rawCounts": result.raw_counts,
        "hlint_available": result.hlint.available,
    }


def render_report(result: ScoreResult) -> str:
    files = result.files_scanned
    lines = [
        "# Functional Purity Report",
        "",
        f"Score: {result.score}/100",
        "",
        "## Formula",
        "",
        f"`{FORMULA}`",
        "",
        "## Penalties",
        "",
        "| Metric | Raw count | Penalty | Cap |",
        "| --- | ---: | ---: | ---: |",
        f"| IO leakage outside expected modules | {result.raw_counts['ioLeakSignatures']} | {result.penalties['ioPenalty']} | 20 |",
        f"| FFI leakage outside OS modules | {result.raw_counts['ffiLeakImports']} | {result.penalties['ffiPenalty']} | 30 |",
        f"| Partial functions in `src/` | {result.raw_counts['partialFunctionOccurrences']} | {result.penalties['partialPenalty']} | 20 |",
        f"| Suspicious app words in `bridge/*.c` | {result.raw_counts['cSuspiciousMatches']} | {result.penalties['cPenalty']} | 20 |",
        f"| HLint hints | {result.raw_counts['hlintHints']} | {result.penalties['hlintPenalty']} | 15 |",
        "",
        "## Rewards",
        "",
        f"Pure core test coverage reward: {result.test_reward}/25",
        "",
        "| Reward item | Covered |",
        "| --- | --- |",
    ]

    for name, covered in result.test_reward_items.items():
        lines.append(f"| {name} | {'yes' if covered else 'no'} |")

    lines.extend(
        [
            "",
            "## HLint",
            "",
            f"- available: {str(result.hlint.available).lower()}",
            f"- hints: {result.hlint.hints}",
            "",
            "## Files scanned",
            "",
        ]
    )

    for group in ["app", "src", "tests", "bridge_c"]:
        lines.append(f"### {group}")
        lines.append("")
        for path in files[group]:
            lines.append(f"- `{path}`")
        if not files[group]:
            lines.append("- none")
        lines.append("")

    lines.extend(
        [
            "## Warnings",
            "",
        ]
    )
    lines.extend(f"- {warning}" for warning in result.warnings)

    lines.extend(
        [
            "",
            "## Known limitations",
            "",
            "- This is a deterministic heuristic, not a proof of purity.",
            "- IO in expected boundary modules is not judged further.",
            "- Haskell comments and strings are stripped with a small scanner, not a full parser.",
            "- C bridge word matches are suspicious hints, not proof of misplaced app logic.",
            "- HLint is optional; when unavailable, no HLint penalty is applied.",
            "- The score does not prove duplicate helper equivalence.",
            "",
        ]
    )
    return "\n".join(lines)


def color_for_score(score: int) -> str:
    if score >= 90:
        return "brightgreen"
    if score >= 80:
        return "green"
    if score >= 70:
        return "yellowgreen"
    if score >= 60:
        return "yellow"
    if score >= 50:
        return "orange"
    return "red"


def module_name_from_text(text: str) -> str | None:
    match = re.search(r"^\s*module\s+([A-Za-z0-9_.']+)", text, flags=re.MULTILINE)
    return match.group(1) if match else None


def module_name_from_path(path: str) -> str:
    parts = Path(path).with_suffix("").parts
    if "src" in parts:
        parts = parts[parts.index("src") + 1 :]
    return ".".join(parts)


def numbered_lines(text: str) -> Iterable[tuple[int, str]]:
    for line_number, line in enumerate(text.splitlines(), start=1):
        yield line_number, line


def clamp(low: int, high: int, value: int) -> int:
    return max(low, min(high, value))


def posix_path(path: Path) -> str:
    return path.as_posix()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compute Bearilo's functional purity score.")
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--tests", type=Path, required=True)
    parser.add_argument("--bridge", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--app", type=Path, default=Path("app"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = read_repository_files(args.src, args.tests, args.bridge, args.app)
    hlint = run_hlint(args.app, args.src, args.tests)
    result = compute_score(files, hlint)
    write_outputs(args.out, args.report, result)
    print(f"Functional purity score: {result.score}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
