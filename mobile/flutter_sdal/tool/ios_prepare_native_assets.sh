#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
NATIVE_ASSETS_DIR="$APP_ROOT/${FLUTTER_BUILD_DIR:-build}/native_assets/ios"

/usr/bin/python3 - "$APP_ROOT" "$NATIVE_ASSETS_DIR" <<'PY'
import os
import plistlib
import shutil
import sys
from pathlib import Path

app_root = Path(sys.argv[1])
native_assets_dir = Path(sys.argv[2])

target_framework = native_assets_dir / "objective_c.framework"
target_binary = target_framework / "objective_c"
if target_binary.exists():
    sys.exit(0)

candidates = sorted(
    (app_root / ".dart_tool" / "hooks_runner" / "shared" / "objective_c" / "build").glob("*/objective_c.dylib"),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)
if not candidates:
    raise SystemExit(
        "Native asset objective_c.framework is required, but objective_c.dylib was not found under .dart_tool/hooks_runner."
    )

target_framework.mkdir(parents=True, exist_ok=True)
shutil.copy2(candidates[0], target_binary)
plist = {
    "CFBundleDevelopmentRegion": "en",
    "CFBundleExecutable": "objective_c",
    "CFBundleIdentifier": "org.dartlang.objective-c",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "objective_c",
    "CFBundlePackageType": "FMWK",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "MinimumOSVersion": os.environ.get("IPHONEOS_DEPLOYMENT_TARGET", "15.0"),
}
with (target_framework / "Info.plist").open("wb") as handle:
    plistlib.dump(plist, handle)
PY

find "$NATIVE_ASSETS_DIR" -name "*.framework" -exec xattr -cr {} \; 2>/dev/null || true
