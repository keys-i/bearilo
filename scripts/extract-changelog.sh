#!/usr/bin/env bash
set -euo pipefail

tag=${1:?usage: scripts/extract-changelog.sh TAG [CHANGELOG] [OUTPUT]}
changelog=${2:-CHANGELOG.md}
output=${3:-release-notes.md}
version=${tag#v}
tmp="${output}.tmp"

awk -v version="$version" '
function heading_level(line) {
  match(line, /^#+/)
  return RLENGTH
}

function heading_version(line, text, bracketed, parts) {
  if (line !~ /^#{1,6}[[:space:]]+/) {
    return ""
  }

  text = line
  sub(/^#{1,6}[[:space:]]+/, "", text)

  if (text ~ /^\[[^]]+\]/) {
    bracketed = text
    sub(/^\[/, "", bracketed)
    sub(/\].*/, "", bracketed)
    return bracketed
  }

  split(text, parts, /[[:space:]]+/)
  return parts[1]
}

BEGIN {
  found = 0
  in_section = 0
  target_level = 0
}

{
  if ($0 ~ /^#{1,6}[[:space:]]+/) {
    current_level = heading_level($0)

    if (in_section && current_level <= target_level) {
      exit
    }

    if (!in_section && heading_version($0) == version) {
      found = 1
      in_section = 1
      target_level = current_level
    }
  }

  if (in_section) {
    print
  }
}

END {
  if (!found) {
    exit 42
  }
}
' "$changelog" > "$tmp" || {
  status=$?
  rm -f "$tmp"
  if [ "$status" -eq 42 ]; then
    echo "No CHANGELOG.md section found for $version" >&2
  fi
  exit "$status"
}

mv "$tmp" "$output"
