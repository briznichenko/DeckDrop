#!/bin/bash
#
#  build.sh
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$project_dir/dist"
build_dir="${TMPDIR:-/tmp}/deck-drop-build"
swift build --package-path "$project_dir" --scratch-path "$build_dir" -c release -debug-info-format none
binary_dir="$(swift build --package-path "$project_dir" --scratch-path "$build_dir" -c release --show-bin-path)"
app_dir="$output_dir/Deck Drop.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/DeckDrop" "$app_dir/Contents/MacOS/DeckDrop"
cp "$project_dir/DeckDrop/Resources/Info.plist" "$app_dir/Contents/Info.plist"
if [ -f "$project_dir/DeckDrop/Resources/DeckDrop.icns" ]; then
    cp "$project_dir/DeckDrop/Resources/DeckDrop.icns" "$app_dir/Contents/Resources/DeckDrop.icns"
fi
codesign --force --sign - "$app_dir"
echo "Built: $app_dir"
