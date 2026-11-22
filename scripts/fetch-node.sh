#!/usr/bin/env bash
# Скачивает готовый Node 24 для iOS (nodejs-mobile) в vendor/.
# Нужен только в CI и на Mac; в Windows не запускается.
set -euo pipefail
version="24.20.0-0"
sha256="f97c5f368f5982fdc062b0f97d96d7696f94dbaf286fbd0d3c515b596088bca8"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/vendor/nodejs-mobile"
zip="$dir/nodejs-mobile-ios-$version.zip"
mkdir -p "$dir"
if [ ! -f "$zip" ]; then
  curl -fL --retry 3 -o "$zip.part" \
    "https://github.com/digidem/nodejs-mobile/releases/download/v$version/nodejs-mobile-ios-$version.zip"
  mv "$zip.part" "$zip"
fi
echo "$sha256  $zip" | shasum -a 256 -c -
rm -rf "$dir/NodeMobile.xcframework"
unzip -q -o "$zip" -d "$dir"
test -d "$dir/NodeMobile.xcframework"
echo "NodeMobile.xcframework: $dir/NodeMobile.xcframework"
