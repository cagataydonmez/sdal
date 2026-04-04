#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/cagataydonmez/flutter/bin/flutter}"
DEVICE_NAME="${1:-iPhone 16 Pro 26.4}"

cd "$ROOT_DIR"
export COPYFILE_DISABLE=1

"$FLUTTER_BIN" pub get
cd ios
pod install
cd ..
"$FLUTTER_BIN" run -d "$DEVICE_NAME"
