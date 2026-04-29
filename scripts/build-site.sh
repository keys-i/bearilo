#!/usr/bin/env bash
set -euo pipefail

site_dir="site"
output="$site_dir/index.html"

rm -rf "$site_dir"
mkdir -p "$site_dir"

cat > "$output" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bearilo</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #f6f5f1;
      --fg: #202124;
      --muted: #5b6068;
      --panel: #ffffff;
      --border: #d9d7cf;
      --code: #f0eee8;
      --link: #1d5fb8;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #111315;
        --fg: #e8e6df;
        --muted: #aaa69d;
        --panel: #1a1d20;
        --border: #33373d;
        --code: #22262b;
        --link: #8ab4f8;
      }
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: var(--bg);
      color: var(--fg);
      font: 16px/1.65 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    main {
      width: min(920px, calc(100% - 32px));
      margin: 0 auto;
      padding: 48px 0 64px;
    }

    a {
      color: var(--link);
    }

    h1,
    h2,
    h3 {
      line-height: 1.2;
    }

    h1 {
      font-size: 2.4rem;
    }

    h2 {
      margin-top: 2.4rem;
      border-bottom: 1px solid var(--border);
      padding-bottom: 0.35rem;
    }

    p,
    li {
      color: var(--fg);
    }

    table {
      width: 100%;
      border-collapse: collapse;
      display: block;
      overflow-x: auto;
    }

    th,
    td {
      border-bottom: 1px solid var(--border);
      padding: 0.5rem;
      text-align: left;
      vertical-align: top;
    }

    code,
    pre {
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
    }

    code {
      background: var(--code);
      border-radius: 4px;
      padding: 0.1rem 0.3rem;
    }

    pre {
      overflow-x: auto;
      white-space: pre-wrap;
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 1rem;
    }

    pre code {
      background: transparent;
      padding: 0;
    }

    blockquote {
      margin-left: 0;
      border-left: 4px solid var(--border);
      padding-left: 1rem;
      color: var(--muted);
    }

    img {
      max-width: 100%;
    }
  </style>
</head>
<body>
<main>
HTML

if command -v pandoc >/dev/null 2>&1; then
  pandoc --from gfm --to html README.md >> "$output"
else
  # Fallback: publish README as escaped preformatted text when pandoc is not installed.
  printf '<pre>\n' >> "$output"
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' README.md >> "$output"
  printf '\n</pre>\n' >> "$output"
fi

cat >> "$output" <<'HTML'
</main>
</body>
</html>
HTML

if [ -d assets ]; then
  cp -R assets "$site_dir/"
fi

: > "$site_dir/.nojekyll"
