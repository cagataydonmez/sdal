#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
FLUTTER_BIN="${FLUTTER_BIN:-$HOME/Developer/flutter/bin/flutter}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.sdal.flutterSdal}"
ANDROID_PACKAGE_ID="${ANDROID_PACKAGE_ID:-com.sdal.flutter_sdal}"
IOS_RELEASE_BUILD_DIR_ABS="${IOS_RELEASE_BUILD_DIR_ABS:-$HOME/Library/Caches/flutter_sdal_ios_build}"
FLUTTER_BUILD_DIR_REL="${FLUTTER_BUILD_DIR_REL:-../../../../Library/Caches/flutter_sdal_flutter_build}"
IOS_SIGNING_IDENTITY_SHA="${IOS_SIGNING_IDENTITY_SHA:-}"

# TestFlight / App Store Connect
IOS_TEAM_ID="${IOS_TEAM_ID:-}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
IOS_ARCHIVE_DIR="${IOS_ARCHIVE_DIR:-$HOME/Library/Caches/flutter_sdal_ios_archives}"

# Android GitHub Release
GITHUB_REPO="${GITHUB_REPO:-}"

PREV_BUILD_DIR=""
PREV_BUILD_DIR_SET=0
VERSION_MAJOR_SELECTED=""
VERSION_MINOR_SELECTED=""
VERSION_NEXT_BUILD=""
APP_VERSION_PENDING=0
CLEAN_BUILD_CACHES=0
RESET_INSTALLED_APP=0

print_help() {
  cat <<'EOF'
Usage: ./tool/install_local.sh

Interactive launcher for:
1. iPhone (cable or wireless) — debug or release install
2. iOS Simulator — debug
3. Android Emulator — debug or release
4. TestFlight — archive, export IPA, upload to App Store Connect
5. Android GitHub Release — flutter build apk + gh release create
6. Apple Watch (WiFi) — build iOS + Watch, embed Watch into Runner.app, install on iPhone
7. watchOS TestFlight — embeds watch app in iOS IPA; runs TestFlight flow

Behavior:
- All options prompt for a version bump before building.
- iPhone release builds into ~/Library/Caches to avoid Desktop/iCloud xattrs breaking codesign.
- The script restores your previous global flutter build-dir setting on exit.

TestFlight required env vars:
  IOS_TEAM_ID    — Apple Developer Team ID (Membership → Team ID)
  ASC_KEY_ID     — App Store Connect API Key ID
  ASC_ISSUER_ID  — App Store Connect API Issuer ID
  ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 must exist

Android GitHub Release required:
  gh CLI installed and authenticated (gh auth login)
  GITHUB_REPO=owner/repo  (or auto-detected from git remote origin)
  Android signing configured in android/key.properties (optional for sideload APKs)
EOF
}

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

log_testflight_signing_summary() {
  local ipa_path="$1"
  local work_dir app_dir profile_path entitlements_plist entitlements_json profile_plist
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sdal_ipa_signing.XXXXXX")"

  log ""
  log "Signing summary from exported IPA:"
  log "IPA: $ipa_path"

  unzip -q "$ipa_path" -d "$work_dir"
  app_dir="$(find "$work_dir/Payload" -maxdepth 1 -name '*.app' -type d | head -1)"
  [[ -d "$app_dir" ]] || die "Could not inspect IPA: .app bundle not found."

  profile_path="$app_dir/embedded.mobileprovision"
  entitlements_plist="$work_dir/entitlements.plist"
  profile_plist="$work_dir/profile.plist"

  if codesign -d --entitlements :- "$app_dir" >"$entitlements_plist" 2>/dev/null; then
    entitlements_json="$(plutil -convert json -o - "$entitlements_plist" 2>/dev/null || printf '{}')"
    /usr/bin/python3 - "$entitlements_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1] or '{}')
for key in [
    'application-identifier',
    'com.apple.developer.team-identifier',
    'aps-environment',
    'com.apple.developer.devicecheck.appattest-environment',
]:
    value = data.get(key, '')
    if isinstance(value, list):
        value = ','.join(str(item) for item in value)
    print(f'  entitlement.{key}={value}')
PY
  else
    log "  [WARN] Could not read codesign entitlements."
  fi

  if [[ -f "$profile_path" ]]; then
    security cms -D -i "$profile_path" >"$profile_plist"
    /usr/bin/python3 - "$profile_plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], 'rb') as fh:
    profile = plistlib.load(fh)
ent = profile.get('Entitlements') or {}
provisions_all = bool(profile.get('ProvisionsAllDevices'))
provisioned = profile.get('ProvisionedDevices') or []
profile_type = 'App Store'
if provisions_all:
    profile_type = 'Enterprise'
elif provisioned:
    profile_type = 'Ad Hoc/Development'
print(f"  profile.name={profile.get('Name', '')}")
print(f"  profile.uuid={profile.get('UUID', '')}")
print(f"  profile.team={','.join(profile.get('TeamIdentifier') or [])}")
print(f"  profile.type={profile_type}")
print(f"  profile.provisionedDeviceCount={len(provisioned)}")
print(f"  profile.aps-environment={ent.get('aps-environment', '')}")
print(f"  profile.appattest-environment={ent.get('com.apple.developer.devicecheck.appattest-environment', '')}")
print(f"  profile.application-identifier={ent.get('application-identifier', '')}")
PY
  else
    log "  [WARN] embedded.mobileprovision not found in IPA."
  fi

  rm -rf "$work_dir"
}

current_version_parts() {
  local version_line
  version_line="$(awk '/^version: /{print $2; exit}' "$ROOT_DIR/pubspec.yaml")"
  if [[ "$version_line" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
    printf '%s %s %s %s' \
      "${BASH_REMATCH[1]}" \
      "${BASH_REMATCH[2]}" \
      "${BASH_REMATCH[3]}" \
      "${BASH_REMATCH[4]}"
    return
  fi
  die "Could not parse version from $ROOT_DIR/pubspec.yaml"
}

prompt_version_part() {
  local label="$1"
  local current="$2"
  local value
  while true; do
    read -r -p "$label [$current]: " value < /dev/tty
    value="$(trim "$value")"
    if [[ -z "$value" ]]; then
      printf '%s' "$current"
      return
    fi
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      printf '%s' "$value"
      return
    fi
    printf '%s must be a non-negative integer.\n' "$label" >&2
  done
}

write_version_files() {
  local major="$1"
  local minor="$2"
  local build="$3"
  local pubspec_version="${major}.${minor}.0+${build}"
  local version_label="v.${major}.${minor}.${build}"

  /usr/bin/python3 - "$ROOT_DIR" "$pubspec_version" "$version_label" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
pubspec_version = sys.argv[2]
version_label = sys.argv[3]

pubspec_path = root / "pubspec.yaml"
pubspec_text = pubspec_path.read_text(encoding="utf-8")
updated_pubspec = re.sub(
    r"^version:\s+.+$",
    f"version: {pubspec_version}",
    pubspec_text,
    count=1,
    flags=re.MULTILINE,
)
if updated_pubspec == pubspec_text:
    raise SystemExit(f"Failed to update version in {pubspec_path}")
pubspec_path.write_text(updated_pubspec, encoding="utf-8")

version_file_path = root / "lib" / "core" / "version" / "app_version.dart"
version_file_path.parent.mkdir(parents=True, exist_ok=True)
version_file_path.write_text(
    "// Generated by tool/install_local.sh. Keep this in sync with pubspec.yaml.\n\n"
    f"const String appVersionLabel = '{version_label}';\n",
    encoding="utf-8",
)
PY

  log "App version updated to $version_label ($pubspec_version)."
}

prompt_app_version_update() {
  local current_major current_minor current_patch current_build
  read -r current_major current_minor current_patch current_build <<< "$(current_version_parts)"

  printf '\nVersion\n'
  VERSION_MAJOR_SELECTED="$(prompt_version_part "Major version" "$current_major")"
  VERSION_MINOR_SELECTED="$(prompt_version_part "Minor version" "$current_minor")"

  if [[ "$VERSION_MAJOR_SELECTED" != "$current_major" || "$VERSION_MINOR_SELECTED" != "$current_minor" ]]; then
    VERSION_NEXT_BUILD=1
  else
    VERSION_NEXT_BUILD=$((current_build + 1))
  fi

  APP_VERSION_PENDING=1
  log "Next app version: v.${VERSION_MAJOR_SELECTED}.${VERSION_MINOR_SELECTED}.${VERSION_NEXT_BUILD}"
}

apply_app_version_update() {
  if [[ $APP_VERSION_PENDING -ne 1 ]]; then
    return
  fi
  write_version_files \
    "$VERSION_MAJOR_SELECTED" \
    "$VERSION_MINOR_SELECTED" \
    "$VERSION_NEXT_BUILD"
  APP_VERSION_PENDING=0
}

make_temp_json() {
  mktemp -t "flutter_sdal.$1.XXXXXX.json"
}

cleanup() {
  if [[ $PREV_BUILD_DIR_SET -eq 1 ]]; then
    "$FLUTTER_BIN" config --build-dir="$PREV_BUILD_DIR" >/dev/null
  else
    "$FLUTTER_BIN" config --build-dir="" >/dev/null
  fi
}

ensure_flutter_build_dir_override() {
  if [[ -n "${PREV_BUILD_DIR:-}" || $PREV_BUILD_DIR_SET -eq 1 ]]; then
    return
  fi

  local current
  current="$("$FLUTTER_BIN" config --list 2>/dev/null | awk -F': ' '/^  build-dir: /{print $2}')"
  if [[ -n "$current" && "$current" != "(Not set)" ]]; then
    PREV_BUILD_DIR="$current"
    PREV_BUILD_DIR_SET=1
  fi

  trap cleanup EXIT
  "$FLUTTER_BIN" config --build-dir="$FLUTTER_BUILD_DIR_REL" >/dev/null
}

prepare_flutter() {
  export COPYFILE_DISABLE=1
  export COPY_EXTENDED_ATTRIBUTES_DISABLE=1
  cd "$ROOT_DIR"
  "$FLUTTER_BIN" pub get
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local answer suffix="[y/N]"
  if [[ "$default" =~ ^[Yy]$ ]]; then
    suffix="[Y/n]"
  fi
  read -r -p "$prompt $suffix " answer < /dev/tty
  answer="$(trim "$answer")"
  if [[ -z "$answer" ]]; then
    [[ "$default" =~ ^[Yy]$ ]]
    return
  fi
  [[ "$answer" =~ ^[Yy]$ ]]
}

prompt_local_cleanup_options() {
  printf '\nClean install options\n'
  printf '  Recommended when auth/Firebase/device-id changes seem stale.\n'
  if prompt_yes_no "Clean Flutter/Xcode build caches before building?" "Y"; then
    CLEAN_BUILD_CACHES=1
  fi
  if prompt_yes_no "Uninstall the existing app from the selected device before install? This resets local app data." "N"; then
    RESET_INSTALLED_APP=1
  fi
}

clean_build_caches_if_requested() {
  if [[ $CLEAN_BUILD_CACHES -ne 1 ]]; then
    return
  fi

  log "Cleaning Flutter/Xcode build caches..."
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" clean
  )
  rm -rf "$ROOT_DIR/build"
  rm -rf "$ROOT_DIR/.dart_tool"
  rm -f "$ROOT_DIR/ios/Flutter/Generated.xcconfig"
  rm -f "$ROOT_DIR/ios/Flutter/flutter_export_environment.sh"
  rm -rf "$ROOT_DIR/ios/build"
  rm -rf "$ROOT_DIR/$FLUTTER_BUILD_DIR_REL"
  rm -rf "$HOME/Library/Caches/flutter_sdal_flutter_build"
  rm -rf "$IOS_RELEASE_BUILD_DIR_ABS"
  rm -rf "$IOS_ARCHIVE_DIR/build_objroot"
  find "$HOME/Library/Developer/Xcode/DerivedData" \
    -maxdepth 1 \
    -type d \
    \( -name 'Runner-*' -o -name 'flutter_sdal*' -o -name 'flutter_sdal_ios*' \) \
    -exec rm -rf {} + 2>/dev/null || true
  log "Build caches cleaned."
  CLEAN_BUILD_CACHES=0
}

uninstall_ios_app_if_requested() {
  local device_identifier="$1"
  if [[ $RESET_INSTALLED_APP -ne 1 ]]; then
    return
  fi
  log "Uninstalling existing iOS app from device, if present..."
  xcrun devicectl device uninstall app \
    --device "$device_identifier" \
    "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
}

uninstall_ios_simulator_app_if_requested() {
  local udid="$1"
  if [[ $RESET_INSTALLED_APP -ne 1 ]]; then
    return
  fi
  log "Uninstalling existing simulator app, if present..."
  xcrun simctl uninstall "$udid" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
}

uninstall_android_app_if_requested() {
  local device_id="$1"
  if [[ $RESET_INSTALLED_APP -ne 1 ]]; then
    return
  fi
  log "Uninstalling existing Android app from device, if present..."
  adb -s "$device_id" uninstall "$ANDROID_PACKAGE_ID" >/dev/null 2>&1 || true
}

prepare_ios() {
  clean_build_caches_if_requested
  prepare_flutter
  (
    cd "$IOS_DIR"
    if [[ -d Pods ]]; then
      pod install
    else
      pod install --repo-update
    fi
  )
}

prompt_number() {
  local max="$1"
  local prompt="${2:-Choose: }"
  local choice
  while true; do
    read -r -p "$prompt" choice < /dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      printf '%s' "$choice"
      return
    fi
    printf 'Enter a number between 1 and %s.\n' "$max" >&2
  done
}

select_from_entries() {
  local title="$1"
  shift
  local -a entries=("$@")
  local total="${#entries[@]}"
  (( total > 0 )) || die "No entries available for $title"

  printf '\n%s\n' "$title" >&2
  local index=1
  local entry label
  for entry in "${entries[@]}"; do
    label="${entry%%|||*}"
    printf '  %d. %s\n' "$index" "$label" >&2
    ((index++))
  done

  local selected
  selected="$(prompt_number "$total" "Choose: ")"
  printf '%s' "${entries[$((selected - 1))]}"
}

load_entries() {
  entries=()
  local line
  while IFS= read -r line; do
    entries+=("$line")
  done < <("$@")
}

json_to_entries() {
  local script="$1"
  local input_file="$2"
  /usr/bin/python3 - "$input_file" "$script" <<'PY'
import json
import sys

input_path = sys.argv[1]
mode = sys.argv[2]

with open(input_path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

if mode == "devicectl":
    for device in payload.get("result", {}).get("devices", []):
        props = device.get("deviceProperties", {})
        hardware = device.get("hardwareProperties", {})
        conn = device.get("connectionProperties", {})
        label = " | ".join(
            [
                props.get("name", device.get("identifier", "unknown")),
                hardware.get("marketingName", hardware.get("productType", "unknown")),
                f"iOS {props.get('osVersionNumber', '?')}",
                conn.get("transportType", "unknown"),
            ]
        )
        print(f"{label}|||{device['identifier']}")
elif mode == "devicectl-watch":
    for device in payload.get("result", {}).get("devices", []):
        props = device.get("deviceProperties", {})
        hardware = device.get("hardwareProperties", {})
        conn = device.get("connectionProperties", {})
        product_type = hardware.get("productType", "")
        # watchOS devices have productType starting with "Watch"
        if not (hardware.get("platform", "").lower() == "watchos" or
                "watch" in product_type.lower() or
                "watch" in hardware.get("marketingName", "").lower()):
            continue
        label = " | ".join(
            [
                props.get("name", device.get("identifier", "unknown")),
                hardware.get("marketingName", hardware.get("productType", "unknown")),
                f"watchOS {props.get('osVersionNumber', '?')}",
                conn.get("transportType", "unknown"),
            ]
        )
        print(f"{label}|||{device['identifier']}")
elif mode == "flutter-ios":
    for device in payload:
        if device.get("targetPlatform") == "ios" and not device.get("emulator", False):
            label = f"{device['name']} | {device['sdk']}"
            print(f"{label}|||{device['id']}")
elif mode == "flutter-android-running":
    for device in payload:
        if str(device.get("targetPlatform", "")).startswith("android") and device.get("emulator", False):
            label = f"{device['name']} | {device['sdk']} | {device['id']}"
            print(f"{label}|||{device['id']}")
elif mode == "simctl":
    devices = payload.get("devices", {})
    for runtime, runtime_devices in sorted(devices.items()):
        if ".iOS-" not in runtime:
            continue
        runtime_label = runtime.split(".iOS-")[-1].replace("-", ".")
        for device in runtime_devices:
            if not device.get("isAvailable"):
                continue
            label = " | ".join(
                [
                    device.get("name", device.get("udid", "unknown")),
                    f"iOS {runtime_label}",
                    device.get("state", "unknown"),
                ]
            )
            print(f"{label}|||{device['udid']}")
PY
}

get_watch_devices() {
  local tmp
  tmp="$(make_temp_json devicectl-watch-devices)"
  xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1 || true
  if [[ -s "$tmp" ]]; then
    json_to_entries "devicectl-watch" "$tmp" 2>/dev/null || true
  fi
  rm -f "$tmp"
}

get_ios_release_devices() {
  local tmp
  tmp="$(make_temp_json flutter-ios-release-devices)"
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" devices --machine > "$tmp"
  )
  json_to_entries "flutter-ios" "$tmp"
  rm -f "$tmp"
}

get_ios_debug_devices() {
  local tmp
  tmp="$(make_temp_json flutter-ios-devices)"
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" devices --machine > "$tmp"
  )
  json_to_entries "flutter-ios" "$tmp"
  rm -f "$tmp"
}

get_ios_simulator_entries() {
  local tmp
  tmp="$(make_temp_json simctl-devices)"
  xcrun simctl list devices available --json > "$tmp"
  json_to_entries "simctl" "$tmp"
  rm -f "$tmp"
}

get_android_emulator_entries() {
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" emulators 2>/dev/null
  ) | awk -F'•' '
    NF >= 4 {
      id=$1; name=$2; platform=$4;
      gsub(/^[ \t]+|[ \t]+$/, "", id);
      gsub(/^[ \t]+|[ \t]+$/, "", name);
      gsub(/^[ \t]+|[ \t]+$/, "", platform);
      if (platform == "android") {
        printf "%s | %s|||%s\n", name, id, id;
      }
    }
  '
}

boot_ios_simulator() {
  local udid="$1"
  log "Opening Simulator.app."
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
}

find_running_android_emulator() {
  local tmp result
  tmp="$(make_temp_json flutter-android-check)"
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" devices --machine > "$tmp" 2>/dev/null
  ) || true
  result="$(/usr/bin/python3 - "$tmp" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        devices = json.load(fh)
    for d in devices:
        if str(d.get("targetPlatform", "")).startswith("android") and d.get("emulator", False):
            print(d["id"])
            break
except Exception:
    pass
PY
  )"
  rm -f "$tmp"
  printf '%s' "$result"
}

wait_for_running_android_emulator() {
  local attempts=60 result
  while (( attempts > 0 )); do
    result="$(find_running_android_emulator)"
    if [[ -n "$result" ]]; then
      printf '%s' "$result"
      return
    fi
    attempts=$((attempts - 1))
    sleep 2
  done
  die "Android emulator did not appear in flutter devices."
}

wait_for_android_emulator() {
  local attempts=60
  local tmp entries
  while (( attempts > 0 )); do
    tmp="$(make_temp_json flutter-android-devices)"
    (
      cd "$ROOT_DIR"
      "$FLUTTER_BIN" devices --machine > "$tmp"
    )
    entries="$(json_to_entries "flutter-android-running" "$tmp" || true)"
    rm -f "$tmp"
    if [[ -n "$entries" ]]; then
      printf '%s' "$entries"
      return
    fi
    attempts=$((attempts - 1))
    sleep 2
  done
  die "Android emulator did not appear in flutter devices."
}

resolve_signing_identity_sha() {
  if [[ -n "$IOS_SIGNING_IDENTITY_SHA" ]]; then
    printf '%s' "$IOS_SIGNING_IDENTITY_SHA"
    return
  fi

  local sha
  sha="$(security find-identity -v -p codesigning | awk '/Apple Development:/ {print $2; exit}')"
  [[ -n "$sha" ]] || die "No Apple Development signing identity found."
  printf '%s' "$sha"
}

build_sign_install_launch_ios_release() {
  local device_identifier="$1"
  local sign_sha xcent_path framework

  prepare_ios

  log "Building signed iPhone release into $IOS_RELEASE_BUILD_DIR_ABS."
  (
    cd "$IOS_DIR"
    xcodebuild \
      -configuration Release \
      -allowProvisioningUpdates \
      -allowProvisioningDeviceRegistration \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      "BUILD_DIR=$IOS_RELEASE_BUILD_DIR_ABS" \
      "OBJROOT=$IOS_RELEASE_BUILD_DIR_ABS" \
      -sdk iphoneos \
      -destination generic/platform=iOS \
      FLUTTER_SUPPRESS_ANALYTICS=true \
      COMPILER_INDEX_STORE_ENABLE=NO
  )

  sign_sha="$(resolve_signing_identity_sha)"
  xcent_path="$IOS_RELEASE_BUILD_DIR_ABS/Runner.build/Release-iphoneos/Runner.build/Runner.app.xcent"
  [[ -f "$xcent_path" ]] || die "Missing entitlements file: $xcent_path"

  log "Re-signing embedded frameworks with $sign_sha."
  while IFS= read -r framework; do
    codesign --force --sign "$sign_sha" --timestamp=none "$framework"
  done < <(find "$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app/Frameworks" -maxdepth 1 -type d -name '*.framework' | sort)

  log "Re-signing app bundle."
  codesign \
    --force \
    --sign "$sign_sha" \
    --entitlements "$xcent_path" \
    --timestamp=none \
    --generate-entitlement-der \
    "$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app"

  log "Installing release app on device."
  xcrun devicectl device install app \
    --device "$device_identifier" \
    "$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app"

  log "Launching release app on device."
  xcrun devicectl device process launch \
    --device "$device_identifier" \
    --terminate-existing \
    "$IOS_BUNDLE_ID"
}

run_flutter_mode() {
  local mode="$1"
  local device_id="$2"
  shift 2

  clean_build_caches_if_requested
  prepare_flutter

  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" run "--$mode" --device-timeout 120 -d "$device_id" "$@"
  )
}

run_ios_debug() {
  local device_id="$1"
  ensure_flutter_build_dir_override
  prepare_ios
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" run --debug --device-timeout 120 -d "$device_id"
  )
}

print_phone_instructions() {
  cat <<'EOF'

Before installing on iPhone:
- Unlock the iPhone.
- If using cable: connect it and trust this Mac if prompted.
- If using wireless: keep Mac and iPhone on the same network and paired in Xcode > Window > Devices and Simulators.
- If the device does not appear, open Xcode once and confirm Developer Mode / pairing.
EOF
}

print_android_instructions() {
  cat <<'EOF'

Android emulator flow:
- The script will launch the selected emulator automatically.
- If emulator launch fails, open Android Studio > Device Manager and start an AVD manually, then rerun this script.
EOF
}

print_testflight_instructions() {
  cat <<'EOF'

TestFlight build & upload flow:
  1. flutter pub get + pod install
  2. xcodebuild archive  (Release, App Store SDK)
  3. xcodebuild -exportArchive  (app-store-connect method)
  4. xcrun altool --upload-app  (App Store Connect API)

One-time prerequisites (script will check each):
  a) Active Apple Developer Program membership
  b) App record created in App Store Connect (appstoreconnect.apple.com)
  c) Distribution certificate installed in your Keychain
     → Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution
  d) IOS_TEAM_ID env var set  (developer.apple.com → Account → Membership)
  e) ASC_KEY_ID + ASC_ISSUER_ID env vars set
     → App Store Connect → Users and Access → Integrations → App Store Connect API
  f) AuthKey_<ASC_KEY_ID>.p8 placed at:
     ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8

Add to your ~/.zshrc (or ~/.bash_profile):
  export IOS_TEAM_ID=XXXXXXXXXX
  export ASC_KEY_ID=XXXXXXXXXX
  export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
EOF
}

check_testflight_prereqs() {
  local ok=1

  if [[ -z "$IOS_TEAM_ID" ]]; then
    printf '\n[MISSING] IOS_TEAM_ID is not set.\n'
    printf '  1. Go to: https://developer.apple.com/account\n'
    printf '  2. Click "Membership Details"\n'
    printf '  3. Copy "Team ID"\n'
    printf '  4. Add to ~/.zshrc:  export IOS_TEAM_ID=<your-team-id>\n'
    printf '  5. Run: source ~/.zshrc\n'
    ok=0
  else
    printf '[OK] IOS_TEAM_ID = %s\n' "$IOS_TEAM_ID"
  fi

  if [[ -z "$ASC_KEY_ID" ]]; then
    printf '\n[MISSING] ASC_KEY_ID is not set.\n'
    printf '  1. Go to: https://appstoreconnect.apple.com/access/integrations/api\n'
    printf '  2. Click "+" to create a new key (Role: App Manager or Developer)\n'
    printf '  3. Copy the "Key ID"\n'
    printf '  4. Add to ~/.zshrc:  export ASC_KEY_ID=<key-id>\n'
    ok=0
  else
    printf '[OK] ASC_KEY_ID = %s\n' "$ASC_KEY_ID"
  fi

  if [[ -z "$ASC_ISSUER_ID" ]]; then
    printf '\n[MISSING] ASC_ISSUER_ID is not set.\n'
    printf '  1. Go to: https://appstoreconnect.apple.com/access/integrations/api\n'
    printf '  2. Copy the "Issuer ID" shown at the top of the page\n'
    printf '  3. Add to ~/.zshrc:  export ASC_ISSUER_ID=<issuer-id>\n'
    ok=0
  else
    printf '[OK] ASC_ISSUER_ID = %s\n' "$ASC_ISSUER_ID"
  fi

  if [[ -n "$ASC_KEY_ID" ]]; then
    local key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
    if [[ ! -f "$key_path" ]]; then
      printf '\n[MISSING] API private key file not found at:\n'
      printf '  %s\n' "$key_path"
      printf '  Steps:\n'
      printf '  1. Go to: https://appstoreconnect.apple.com/access/integrations/api\n'
      printf '  2. Download the .p8 file for key %s\n' "$ASC_KEY_ID"
      printf '     (Download is only available once — if missed, revoke and create a new key)\n'
      printf '  3. mkdir -p ~/.appstoreconnect/private_keys\n'
      printf '  4. mv ~/Downloads/AuthKey_%s.p8 ~/.appstoreconnect/private_keys/\n' "$ASC_KEY_ID"
      printf '  5. chmod 600 ~/.appstoreconnect/private_keys/AuthKey_%s.p8\n' "$ASC_KEY_ID"
      ok=0
    else
      printf '[OK] API key file found: %s\n' "$key_path"
    fi
  fi

  local dist_cert
  dist_cert="$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Apple Distribution:' || true)"
  if [[ "$dist_cert" -lt 1 ]]; then
    printf '\n[MISSING] No Apple Distribution certificate found in Keychain.\n'
    printf '  1. Open Xcode\n'
    printf '  2. Xcode → Settings → Accounts → select your Apple ID → Manage Certificates\n'
    printf '  3. Click "+" → "Apple Distribution"\n'
    printf '  4. Xcode will generate and install the certificate.\n'
    ok=0
  else
    printf '[OK] Apple Distribution certificate found (%s).\n' "$dist_cert"
  fi

  # Hard stop for any missing env/cert issues before asking the interactive question.
  if [[ $ok -eq 0 ]]; then
    printf '\n---\nFix the items above, then re-run this script.\n'
    return 1
  fi

  # App Store Connect app record check.
  # xcrun altool will fail with error 19 if the app does not exist in App Store Connect.
  # We cannot verify this automatically without a JWT call, so we ask the user explicitly.
  printf '\n[CHECK] App record in App Store Connect\n'
  printf '  The upload will fail if the app has not been created in App Store Connect yet.\n'
  printf '  Bundle ID that will be uploaded: %s\n' "$IOS_BUNDLE_ID"
  printf '\n  If you have NOT created the app yet:\n'
  printf '  1. Go to: https://appstoreconnect.apple.com\n'
  printf '  2. Click "+" → "New App"\n'
  printf '  3. Platform: iOS\n'
  printf '  4. Bundle ID: %s\n' "$IOS_BUNDLE_ID"
  printf '     (If it does not appear in the dropdown, first register it at\n'
  printf '      https://developer.apple.com/account/resources/identifiers/list)\n'
  printf '  5. Fill in name and SKU, click "Create"\n'
  printf '\n'
  local app_confirmed
  read -r -p "Is the app already created in App Store Connect? [y/N] " app_confirmed < /dev/tty
  if [[ ! "$app_confirmed" =~ ^[Yy]$ ]]; then
    printf '\nCreate the app record first, then re-run this script.\n'
    return 1
  fi
  printf '[OK] App record confirmed by user.\n'

  printf '\nAll prerequisites OK. Proceeding with TestFlight build.\n'
  return 0
}

build_archive_export_upload_testflight() {
  # The simulator/debug flows point FLUTTER_BUILD_DIR at a custom cache so debug
  # artefacts don't blow up the project directory. That cache contains native_assets
  # built for the iOS Simulator (LC_BUILD_VERSION platform = IOSSIMULATOR). If the
  # archive picks those up, App Store validation rejects the IPA (error 91169).
  # Reset build-dir to project default and drop Generated.xcconfig so the Xcode
  # Flutter build phase regenerates it and rebuilds native_assets fresh for iOS.
  log "Resetting flutter build-dir for archive (avoids stale simulator native_assets)..."
  "$FLUTTER_BIN" config --build-dir="" >/dev/null 2>&1 || true
  rm -f "$ROOT_DIR/ios/Flutter/Generated.xcconfig"
  rm -rf "$ROOT_DIR/build/native_assets"

  prepare_ios

  mkdir -p "$IOS_ARCHIVE_DIR"
  log "Clearing stale iOS archive intermediates..."
  rm -rf "$IOS_ARCHIVE_DIR/build_objroot"

  local timestamp archive_path export_path export_options_plist
  timestamp="$(date +%Y%m%d_%H%M%S)"
  archive_path="$IOS_ARCHIVE_DIR/Runner_${timestamp}.xcarchive"
  export_path="$IOS_ARCHIVE_DIR/Runner_${timestamp}_ipa"
  export_options_plist="$IOS_ARCHIVE_DIR/ExportOptions_${timestamp}.plist"

  /usr/bin/python3 - "$export_options_plist" "$IOS_TEAM_ID" <<'PY'
from pathlib import Path
import sys

plist_path = Path(sys.argv[1])
team_id = sys.argv[2]
plist_path.parent.mkdir(parents=True, exist_ok=True)
plist_path.write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'
    ' "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0">\n'
    '<dict>\n'
    '    <key>method</key>\n'
    '    <string>app-store-connect</string>\n'
    '    <key>teamID</key>\n'
    f'    <string>{team_id}</string>\n'
    '    <key>uploadBitcode</key>\n'
    '    <false/>\n'
    '    <key>uploadSymbols</key>\n'
    '    <true/>\n'
    '    <key>signingStyle</key>\n'
    '    <string>automatic</string>\n'
    '</dict>\n'
    '</plist>\n',
    encoding="utf-8",
)
PY

  log ""
  log "Step 1/3: Archiving for App Store (this may take a few minutes)..."
  log "Archive path: $archive_path"
  (
    cd "$IOS_DIR"
    xcodebuild \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \
      -archivePath "$archive_path" \
      -allowProvisioningUpdates \
      FLUTTER_SUPPRESS_ANALYTICS=true \
      COMPILER_INDEX_STORE_ENABLE=NO \
      DEVELOPMENT_TEAM="$IOS_TEAM_ID" \
      "OBJROOT=$IOS_ARCHIVE_DIR/build_objroot" \
      archive
  )

  log ""
  log "Step 2/3: Exporting IPA from archive..."
  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options_plist" \
    -allowProvisioningUpdates

  local ipa_path
  ipa_path="$(find "$export_path" -name '*.ipa' | head -1)"
  [[ -f "$ipa_path" ]] || die "IPA not found after export in: $export_path"

  log_testflight_signing_summary "$ipa_path"

  log ""
  log "Step 3/3: Uploading to App Store Connect / TestFlight..."
  log "IPA: $ipa_path"
  log "(Upload may take several minutes depending on app size)"
  xcrun altool \
    --upload-app \
    -f "$ipa_path" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

  log ""
  log "Upload complete!"
  log ""
  log "Next steps:"
  log "  1. Go to: https://appstoreconnect.apple.com → Your App → TestFlight"
  log "  2. Wait for Apple to finish processing (typically 15–30 minutes)"
  log "  3. The build will appear under 'iOS Builds'"
  log "  4. Add internal or external testers as needed"
  log ""
  log "Artifacts saved at:"
  log "  Archive : $archive_path"
  log "  IPA     : $ipa_path"
}

print_android_github_release_instructions() {
  cat <<'EOF'

Android GitHub Release flow:
  1. flutter pub get
  2. flutter build apk --release
  3. gh release create <tag> <apk>  (creates tag + release on GitHub)

One-time prerequisites (script will check each):
  a) gh CLI installed  (brew install gh)
  b) gh authenticated  (gh auth login)
  c) GitHub repo accessible (auto-detected from git remote, or set GITHUB_REPO=owner/repo)
  d) Android signing configured  (optional — unsigned APK works for sideloading)
     → android/key.properties + android/app/build.gradle signingConfigs

Note: Build number is NOT incremented for this flow. Bump the version manually
      via options 1–3, or edit pubspec.yaml before running this option.
EOF
}

check_github_release_prereqs() {
  local ok=1

  if ! command -v gh >/dev/null 2>&1; then
    printf '\n[MISSING] gh CLI is not installed.\n'
    printf '  Install: brew install gh\n'
    ok=0
  else
    printf '[OK] gh CLI found: %s\n' "$(gh --version | head -1)"

    if ! gh auth status >/dev/null 2>&1; then
      printf '\n[MISSING] gh is not authenticated.\n'
      printf '  Run: gh auth login\n'
      printf '  Then re-run this script.\n'
      ok=0
    else
      printf '[OK] gh authenticated.\n'
    fi
  fi

  local repo
  repo="$GITHUB_REPO"
  if [[ -z "$repo" ]]; then
    repo="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null \
      | sed -E 's|.*github\.com[:/]||; s|\.git$||' || true)"
  fi
  if [[ -z "$repo" ]]; then
    printf '\n[MISSING] Cannot determine GitHub repo.\n'
    printf '  Option A: Set env var:  export GITHUB_REPO=owner/repo\n'
    printf '  Option B: Ensure git remote origin points to a GitHub URL.\n'
    ok=0
  else
    printf '[OK] GitHub repo: %s\n' "$repo"
  fi

  if [[ $ok -eq 0 ]]; then
    printf '\n---\nFix the items above, then re-run this script.\n'
    return 1
  fi

  printf '\nAll prerequisites OK. Proceeding with Android release build.\n'
  return 0
}

build_upload_android_github_release() {
  prepare_flutter

  log ""
  log "Step 1/2: Building Android release APK..."
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" build apk --release
  )

  # Locate the APK — search standard path first, then fallback to find
  local apk_path="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  if [[ ! -f "$apk_path" ]]; then
    apk_path="$(find "$ROOT_DIR/build" "$HOME/Library/Caches/flutter_sdal_flutter_build" \
      -name 'app-release.apk' -path '*/flutter-apk/*' 2>/dev/null | head -1 || true)"
  fi
  [[ -f "$apk_path" ]] || die "APK not found after build. Run 'flutter build apk --release' manually to diagnose."

  log "APK: $apk_path"

  # Determine version from pubspec
  local major minor patch build_num
  read -r major minor patch build_num <<< "$(current_version_parts)"
  local tag="v${major}.${minor}.${build_num}"

  # Determine GitHub repo
  local repo="$GITHUB_REPO"
  if [[ -z "$repo" ]]; then
    repo="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null \
      | sed -E 's|.*github\.com[:/]||; s|\.git$||' || true)"
  fi
  [[ -n "$repo" ]] || die "Could not determine GitHub repo. Set GITHUB_REPO=owner/repo"

  # Prompt for release notes
  printf '\nRelease notes (press Enter to auto-generate from recent commits):\n> '
  local notes
  read -r notes < /dev/tty
  if [[ -z "$notes" ]]; then
    notes="$(git -C "$ROOT_DIR" log --oneline -8 2>/dev/null \
      | sed 's/^[a-f0-9]* /- /' || true)"
    [[ -n "$notes" ]] || notes="Release $tag"
  fi

  log ""
  log "Step 2/2: Creating GitHub release $tag in $repo..."
  gh release create "$tag" \
    --repo "$repo" \
    --title "$tag" \
    --notes "$notes" \
    "$apk_path#app-release.apk"

  log ""
  log "Release published!"
  log "  URL : https://github.com/$repo/releases/tag/$tag"
  log "  APK : $apk_path"
}

WATCH_BUNDLE_ID="${WATCH_BUNDLE_ID:-com.sdal.flutterSdal.SdalWatch}"
WATCH_SCHEME="${WATCH_SCHEME:-SdalWatch}"


print_watch_instructions() {
  cat <<'EOF'

Before installing on Apple Watch:
- Keep iPhone unlocked and nearby.
- Make sure the watch and iPhone are on the same Wi-Fi network.
- Watch must be unlocked (wrist detection may lock it — disable if needed).
- The watch app is a standalone watchOS app; it communicates with the iPhone
  via WatchConnectivity to receive the session cookie automatically.
- Pair the watch in Xcode > Window > Devices and Simulators if not already paired.
EOF
}

# Inject loose icon PNGs into a built SdalWatch.app bundle so that App Store Connect
# validation passes. altool checks for files matching *{size}@{scale}x.png directly
# inside the bundle — Assets.car alone is not sufficient for the legacy validator.
inject_watch_icons() {
  local app_bundle="$1"
  local src="$IOS_DIR/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
  [[ -f "$src" ]] || { log "WARNING: iOS source icon not found at $src — skipping icon injection."; return; }

  # (logical_size, scale, pixel_size) — covers every pattern altool validates against
  local -a ICONS=(
    "AppIcon24x24@2x.png:48"
    "AppIcon27.5x27.5@2x.png:55"
    "AppIcon40x40@2x.png:80"
    "AppIcon44x44@2x.png:88"
    "AppIcon50x50@2x.png:100"
    "AppIcon86x86@2x.png:172"
    "AppIcon98x98@2x.png:196"
    "AppIcon108x108@2x.png:216"
    "AppIcon117x117@2x.png:234"
    "AppIcon129x129@2x.png:258"
    "AppIcon1024x1024@1x.png:1024"
  )

  log "  Injecting loose icon PNGs into $(basename "$app_bundle")..."
  for entry in "${ICONS[@]}"; do
    local name="${entry%%:*}"
    local px="${entry##*:}"
    sips -z "$px" "$px" "$src" --out "$app_bundle/$name" >/dev/null 2>&1
  done
}

# Build SdalWatch for a given SDK (watchos or watchsimulator) using -project -target,
# which bypasses the CocoaPods workspace and avoids the Xcode 15+/26 bug where
# embedded watch targets are cross-compiled with the iOS SDK instead of watchOS.
# Outputs the path to the built .app via stdout; all other output goes to stderr.
build_watch_app_for_sdk() {
  local sdk="$1"          # watchos | watchsimulator
  local configuration="$2" # Debug | Release
  local extra_args=("${@:3}")

  local subdir="watchos"
  [[ "$sdk" == "watchsimulator" ]] && subdir="watchsimulator"

  local conf_lower
  conf_lower="$(printf '%s' "$configuration" | tr '[:upper:]' '[:lower:]')"
  local watch_build_dir="$HOME/Library/Caches/flutter_sdal_watch_${subdir}_${conf_lower}"
  mkdir -p "$watch_build_dir"

  (
    cd "$IOS_DIR"
    xcodebuild \
      -project Runner.xcodeproj \
      -target SdalWatch \
      -configuration "$configuration" \
      -sdk "$sdk" \
      "BUILD_DIR=$watch_build_dir" \
      "OBJROOT=$watch_build_dir/build_objroot" \
      COMPILER_INDEX_STORE_ENABLE=NO \
      ONLY_ACTIVE_ARCH=NO \
      "${extra_args[@]}"
  ) >&2

  local app_path
  app_path="$(find "$watch_build_dir" -maxdepth 4 -name 'SdalWatch.app' \
    ! -path '*/SdalWatch.app/*' 2>/dev/null | head -1 || true)"
  printf '%s' "$app_path"
}

build_install_ios_and_watch() {
  local iphone_identifier="$1"

  prepare_ios

  # SdalWatch is now embedded via "Embed Watch Content" Xcode build phase.
  # One workspace build produces Runner.app with SdalWatch.app inside Watch/.

  # ── Step 1: Build Runner.app (embeds SdalWatch automatically) ─────────────
  log ""
  log "Step 1/2: Building Runner.app + embedded SdalWatch (Release)..."
  (
    cd "$IOS_DIR"
    xcodebuild \
      -configuration Release \
      -allowProvisioningUpdates \
      -allowProvisioningDeviceRegistration \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      "BUILD_DIR=$IOS_RELEASE_BUILD_DIR_ABS" \
      "OBJROOT=$IOS_RELEASE_BUILD_DIR_ABS" \
      -destination "id:$iphone_identifier" \
      FLUTTER_SUPPRESS_ANALYTICS=true \
      COMPILER_INDEX_STORE_ENABLE=NO \
      build
  )

  local ios_app_path="$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app"
  [[ -d "$ios_app_path" ]] || die "Runner.app not found after build: $ios_app_path"

  # Verify Watch is embedded
  local watch_check
  watch_check="$(find "$ios_app_path/Watch" -name 'SdalWatch.app' 2>/dev/null | head -1)"
  if [[ -n "$watch_check" ]]; then
    log "SdalWatch.app embedded: $watch_check"
  else
    log "[WARN] SdalWatch.app not found in Runner.app/Watch/ — Watch app will not update."
  fi

  # ── Step 2: Install on iPhone + launch ────────────────────────────────────
  log ""
  log "Step 2/2: Installing Runner.app on iPhone..."
  xcrun devicectl device install app \
    --device "$iphone_identifier" \
    "$ios_app_path"

  log ""
  log "Launching SDAL on iPhone..."
  xcrun devicectl device process launch \
    --device "$iphone_identifier" \
    --terminate-existing \
    "$IOS_BUNDLE_ID"

  log ""
  log "Done!"
  log "SdalWatch will appear on Apple Watch within 1-2 minutes after SDAL launches on iPhone."
  log "If it doesn\'t appear: open the Watch app on iPhone \u2192 Available Apps \u2192 install SdalWatch."
  log "Open SDAL on iPhone \u2014 the Watch app will receive your session automatically."
}
build_archive_export_upload_testflight_with_watch() {
  # SdalWatch is now a proper Embed Watch Content dependency of Runner in the Xcode project.
  # xcodebuild archives both targets together — no manual injection needed.
  # SdalWatch has SDKROOT=watchos in its build settings so the Xcode 15 cross-
  # compilation bug (wrong SDK leaking from the iOS scheme) does not apply.

  log ""
  log "Resetting flutter build-dir for archive (avoids stale simulator native_assets)..."
  "$FLUTTER_BIN" config --build-dir="" >/dev/null 2>&1 || true
  rm -f "$ROOT_DIR/ios/Flutter/Generated.xcconfig"
  rm -rf "$ROOT_DIR/build/native_assets"

  prepare_ios

  mkdir -p "$IOS_ARCHIVE_DIR"
  log "Clearing stale iOS archive intermediates..."
  rm -rf "$IOS_ARCHIVE_DIR/build_objroot"

  local timestamp archive_path export_path export_options_plist
  timestamp="$(date +%Y%m%d_%H%M%S)"
  archive_path="$IOS_ARCHIVE_DIR/Runner_${timestamp}.xcarchive"
  export_path="$IOS_ARCHIVE_DIR/Runner_${timestamp}_ipa"
  export_options_plist="$IOS_ARCHIVE_DIR/ExportOptions_${timestamp}.plist"

  /usr/bin/python3 - "$export_options_plist" "$IOS_TEAM_ID" <<'PY'
from pathlib import Path
import sys
plist_path = Path(sys.argv[1])
team_id = sys.argv[2]
plist_path.parent.mkdir(parents=True, exist_ok=True)
plist_path.write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'
    ' "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0">\n'
    '<dict>\n'
    '    <key>method</key>\n'
    '    <string>app-store-connect</string>\n'
    '    <key>teamID</key>\n'
    f'    <string>{team_id}</string>\n'
    '    <key>uploadBitcode</key>\n'
    '    <false/>\n'
    '    <key>uploadSymbols</key>\n'
    '    <true/>\n'
    '    <key>signingStyle</key>\n'
    '    <string>automatic</string>\n'
    '</dict>\n'
    '</plist>\n',
    encoding="utf-8",
)
PY

  log ""
  log "Step 1/3: Archiving iOS Runner + SdalWatch for App Store..."
  log "  (SdalWatch is embedded via Xcode 'Embed Watch Content' phase)"
  log "Archive path: $archive_path"
  (
    cd "$IOS_DIR"
    xcodebuild \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -archivePath "$archive_path" \
      -allowProvisioningUpdates \
      FLUTTER_SUPPRESS_ANALYTICS=true \
      COMPILER_INDEX_STORE_ENABLE=NO \
      DEVELOPMENT_TEAM="$IOS_TEAM_ID" \
      "OBJROOT=$IOS_ARCHIVE_DIR/build_objroot" \
      archive
  )

  # Verify Watch app made it into the archive
  local runner_app_in_archive watch_in_archive
  runner_app_in_archive="$(find "$archive_path/Products/Applications" \
    -maxdepth 1 -name '*.app' 2>/dev/null | head -1)"
  watch_in_archive="$(find "$runner_app_in_archive/Watch" -name 'SdalWatch.app' 2>/dev/null | head -1)"
  if [[ -n "$watch_in_archive" ]]; then
    log "Watch app verified in archive: $watch_in_archive"
  else
    log "[WARN] SdalWatch.app not found in archive — Watch may not deploy to Apple Watch."
  fi

  log ""
  log "Step 2/3: Exporting IPA from archive..."
  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options_plist" \
    -allowProvisioningUpdates

  local ipa_path
  ipa_path="$(find "$export_path" -name '*.ipa' | head -1)"
  [[ -f "$ipa_path" ]] || die "IPA not found after export in: $export_path"

  # Verify Watch app made it into the IPA
  local watch_in_ipa
  watch_in_ipa="$(unzip -l "$ipa_path" 2>/dev/null | grep -c 'SdalWatch' || true)"
  if [[ "$watch_in_ipa" -gt 0 ]]; then
    log "Watch app verified in IPA ($watch_in_ipa files)"
  else
    log "[WARN] SdalWatch not found inside IPA — Watch companion app will NOT be distributed."
  fi

  log_testflight_signing_summary "$ipa_path"

  log ""
  log "Step 3/3: Uploading to App Store Connect / TestFlight..."
  log "IPA: $ipa_path"
  log "(Upload may take several minutes depending on app size)"
  xcrun altool \
    --upload-app \
    -f "$ipa_path" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

  log ""
  log "Done!"
  log ""
  log "Next steps:"
  log "  1. Go to: https://appstoreconnect.apple.com -> Your App -> TestFlight"
  log "  2. Wait for Apple to finish processing (typically 15-30 minutes)"
  log "  3. The build will appear under 'iOS Builds'"
  log "  4. SdalWatch is embedded — iPhone auto-deploys it to Apple Watch"
  log "  5. On Watch: open the App Store app or wait for auto-install"
  log ""
  log "Artifacts saved at:"
  log "  Archive : $archive_path"
  log "  IPA     : $ipa_path"
}

main() {
  require_cmd "$FLUTTER_BIN"
  require_cmd /usr/bin/python3
  require_cmd xcrun

  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    print_help
    exit 0
  fi

  # Select target first so version prompt can be skipped for distribution flows.
  printf '\nTarget type\n'
  printf '  1. iPhone (cable or wireless)\n'
  printf '  2. iOS Simulator\n'
  printf '  3. Android Emulator\n'
  printf '  4. TestFlight (archive + upload to App Store Connect)\n'
  printf '  5. Android GitHub Release (build APK + gh release)\n'
  printf '  6. Apple Watch (WiFi) — iOS + Watch, deploy via iPhone\n'
  printf '  7. watchOS TestFlight (embedded in iOS IPA)\n'
  local target_choice
  target_choice="$(prompt_number 7 "Choose target: ")"

  # Version bump: prompt for all options.
  prompt_app_version_update

  # Build type prompt: only for local flows that support debug/release.
  local build_mode=""
  if [[ "$target_choice" =~ ^[123]$ ]]; then
    local build_choice
    printf '\nBuild type\n'
    printf '  1. Debug\n'
    printf '  2. Release\n'
    build_choice="$(prompt_number 2 "Choose build: ")"
    if [[ "$build_choice" == "1" ]]; then
      build_mode="debug"
    else
      build_mode="release"
    fi
    prompt_local_cleanup_options
  fi

  case "$target_choice" in
    1)
      print_phone_instructions
      if [[ "$build_mode" == "release" ]]; then
        load_entries get_ios_release_devices
        local selected label identifier
        selected="$(select_from_entries "Available iPhone release targets" "${entries[@]}")"
        label="${selected%%|||*}"
        identifier="${selected##*|||}"
        log "Selected: $label"
        apply_app_version_update
        uninstall_ios_app_if_requested "$identifier"
        build_sign_install_launch_ios_release "$identifier"
      else
        load_entries get_ios_debug_devices
        local selected label identifier
        selected="$(select_from_entries "Available iPhone debug targets" "${entries[@]}")"
        label="${selected%%|||*}"
        identifier="${selected##*|||}"
        log "Selected: $label"
        apply_app_version_update
        uninstall_ios_app_if_requested "$identifier"
        run_ios_debug "$identifier"
      fi
      ;;
    2)
      if [[ "$build_mode" == "release" ]]; then
        die "Flutter release mode is not supported on iOS Simulator. Use iPhone + Release, or iOS Simulator + Debug."
      fi
      require_cmd open
      load_entries get_ios_simulator_entries
      local selected label udid
      selected="$(select_from_entries "Available iOS simulators" "${entries[@]}")"
      label="${selected%%|||*}"
      udid="${selected##*|||}"
      log "Selected: $label"
      apply_app_version_update
      boot_ios_simulator "$udid"
      uninstall_ios_simulator_app_if_requested "$udid"
      ensure_flutter_build_dir_override
      prepare_ios
      (
        cd "$ROOT_DIR"
        "$FLUTTER_BIN" run "--$build_mode" --device-timeout 120 -d "$udid"
      )
      ;;
    3)
      print_android_instructions
      local android_device_id
      android_device_id="$(find_running_android_emulator)"
      if [[ -z "$android_device_id" ]]; then
        load_entries get_android_emulator_entries || true
        local selected label emulator_id
        if (( ${#entries[@]} > 0 )); then
          selected="$(select_from_entries "Available Android emulators" "${entries[@]}")"
          label="${selected%%|||*}"
          emulator_id="${selected##*|||}"
          log "Selected: $label"
          (
            cd "$ROOT_DIR"
            "$FLUTTER_BIN" emulators --launch "$emulator_id"
          )
        else
          log "No AVD emulators found via flutter — waiting for a running Android device..."
        fi
        android_device_id="$(wait_for_running_android_emulator)"
      fi
      log "Using Android device: $android_device_id"
      apply_app_version_update
      uninstall_android_app_if_requested "$android_device_id"
      run_flutter_mode "$build_mode" "$android_device_id"
      ;;
    4)
      print_testflight_instructions
      printf '\nChecking prerequisites...\n'
      check_testflight_prereqs || exit 1
      local confirm
      read -r -p "Proceed with TestFlight build and upload? [y/N] " confirm < /dev/tty
      [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
      apply_app_version_update
      build_archive_export_upload_testflight
      ;;
    5)
      print_android_github_release_instructions
      printf '\nChecking prerequisites...\n'
      check_github_release_prereqs || exit 1
      local confirm
      read -r -p "Proceed with Android release build and GitHub upload? [y/N] " confirm < /dev/tty
      [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
      apply_app_version_update
      build_upload_android_github_release
      ;;
    6)
      print_watch_instructions
      print_phone_instructions
      load_entries get_ios_release_devices
      if (( ${#entries[@]} == 0 )); then
        die "No iPhone found. Connect it and pair in Xcode > Window > Devices and Simulators."
      fi
      local selected label identifier
      selected="$(select_from_entries "Available iPhone devices" "${entries[@]}")"
      label="${selected%%|||*}"
      identifier="${selected##*|||}"
      log "Selected: $label"
      prompt_local_cleanup_options
      apply_app_version_update
      build_install_ios_and_watch "$identifier"
      ;;
    7)
      log ""
      log "watchOS TestFlight"
      log "  Archives Runner with embedded SdalWatch, letting Xcode select watchOS for the watch target,"
      log "  then exports the IPA and uploads to App Store Connect."
      log "  App Store Connect links the companion watch app to the iOS app automatically."
      log ""
      print_testflight_instructions
      printf '\nChecking prerequisites...\n'
      check_testflight_prereqs || exit 1
      local confirm
      read -r -p "Proceed with watchOS + iOS TestFlight build and upload? [y/N] " confirm < /dev/tty
      [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
      apply_app_version_update
      build_archive_export_upload_testflight_with_watch
      ;;
  esac
}

main "$@"
