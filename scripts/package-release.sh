#!/usr/bin/env bash
set -euo pipefail

package_name=${1:?usage: scripts/package-release.sh PACKAGE_NAME}
release_dir=${RELEASE_DIR:-dist/release}
staging_dir="$release_dir/$package_name"
archive="$release_dir/$package_name.tar.xz"
binary=$(cabal list-bin exe:bearilo)

rm -rf "$staging_dir" "$archive" "$archive.sha256"
mkdir -p "$staging_dir"

cp "$binary" "$staging_dir/bearilo"
chmod +x "$staging_dir/bearilo"

for file in README.md CHANGELOG.md LICENSE; do
  if [ -f "$file" ]; then
    cp "$file" "$staging_dir/"
  fi
done

tar -cJf "$archive" -C "$release_dir" "$package_name"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$release_dir" && sha256sum "$package_name.tar.xz" > "$package_name.tar.xz.sha256")
else
  (cd "$release_dir" && shasum -a 256 "$package_name.tar.xz" > "$package_name.tar.xz.sha256")
fi
