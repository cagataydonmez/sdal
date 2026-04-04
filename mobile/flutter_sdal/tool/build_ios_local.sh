#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/cagataydonmez/flutter/bin/flutter}"

cd "$ROOT_DIR"
export COPYFILE_DISABLE=1

"$FLUTTER_BIN" pub get
cd ios
pod install
cd ..
"$FLUTTER_BIN" build ios --release --no-codesign
