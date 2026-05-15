#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(dirname -- "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$TOOL_DIR" && pwd)"

# Detect ROOT_DIR: check if script is in tool/ or if called from repo root
if [[ -f "$SCRIPT_DIR/testflight_utils.sh" ]]; then
  # Script is at mobile/flutter_sdal/tool/
  ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
elif [[ -f "mobile/flutter_sdal/tool/testflight_utils.sh" ]]; then
  # Called from repo root
  ROOT_DIR="$(CDPATH= cd -- "mobile/flutter_sdal" && pwd)"
else
  echo "Error: Could not find Flutter project root. Run from repo root or mobile/flutter_sdal/tool/" >&2
  exit 1
fi

source "$SCRIPT_DIR/testflight_utils.sh"
IOS_DIR="$ROOT_DIR/ios"
IOS_PBXPROJ="$IOS_DIR/Runner.xcodeproj/project.pbxproj"
FLUTTER_BIN="${FLUTTER_BIN:-$HOME/Developer/flutter/bin/flutter}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.sdal.flutterSdal}"
ANDROID_PACKAGE_ID="${ANDROID_PACKAGE_ID:-com.sdal.flutter_sdal}"
IOS_RELEASE_BUILD_DIR_ABS="${IOS_RELEASE_BUILD_DIR_ABS:-$HOME/Library/Caches/flutter_sdal_ios_build}"
IOS_SIMULATOR_BUILD_DIR_ABS="${IOS_SIMULATOR_BUILD_DIR_ABS:-$HOME/Library/Caches/flutter_sdal_ios_sim_build}"
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
SIMULATOR_PBXPROJ_BACKUP=""
SIMULATOR_PBXPROJ_PATCHED=0
SIM_PAIR_DRY_RUN="${SIM_PAIR_DRY_RUN:-0}"
SIM_PAIR_AUTO_LOGS="${SIM_PAIR_AUTO_LOGS:-1}"
SIM_PAIR_WATCH_LOGS="${SIM_PAIR_WATCH_LOGS:-0}"
SIM_PAIR_WATCH_APP_PATH=""
SIM_PAIR_WATCH_LOG_PID=""

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
  if [[ -n "${SIM_PAIR_WATCH_LOG_PID:-}" ]]; then
    kill "$SIM_PAIR_WATCH_LOG_PID" >/dev/null 2>&1 || true
    wait "$SIM_PAIR_WATCH_LOG_PID" 2>/dev/null || true
    SIM_PAIR_WATCH_LOG_PID=""
  fi

  if [[ $SIMULATOR_PBXPROJ_PATCHED -eq 1 && -n "$SIMULATOR_PBXPROJ_BACKUP" && -f "$SIMULATOR_PBXPROJ_BACKUP" ]]; then
    cp "$SIMULATOR_PBXPROJ_BACKUP" "$IOS_PBXPROJ"
    rm -f "$SIMULATOR_PBXPROJ_BACKUP"
    SIMULATOR_PBXPROJ_PATCHED=0
  fi

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

disable_runner_watch_embed_for_ios_simulator() {
  if [[ $SIMULATOR_PBXPROJ_PATCHED -eq 1 ]]; then
    return
  fi

  SIMULATOR_PBXPROJ_BACKUP="$(mktemp -t "flutter_sdal.runner_pbxproj.XXXXXX")"
  cp "$IOS_PBXPROJ" "$SIMULATOR_PBXPROJ_BACKUP"

  /usr/bin/python3 - "$IOS_PBXPROJ" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
updated = text.replace(
    "\t\t\t\tWA0012345678901ABCDEF002 /* Embed Watch Content */,\n",
    "",
).replace(
    "\t\t\t\tWA0012345678901ABCDEF004 /* PBXTargetDependency */,\n",
    "",
).replace(
    "\t\t\t\t7CBE429371BD4E21AA16AB37 /* SdalWatch */,\n",
    "",
)
if updated == text:
    raise SystemExit("Runner watch embed/dependency entries were not found in project.pbxproj")
path.write_text(updated, encoding="utf-8")
PY

  SIMULATOR_PBXPROJ_PATCHED=1
  log "Temporarily disabled Runner watch embedding for the iOS Simulator build."
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
  rm -rf "$IOS_SIMULATOR_BUILD_DIR_ABS"
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

patch_generated_xcconfig_for_ios_simulator() {
  local generated="$ROOT_DIR/ios/Flutter/Generated.xcconfig"
  [[ -f "$generated" ]] || return 0
  /usr/bin/python3 - "$generated" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(
    r"^EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]=(.*)$",
    lambda match: "EXCLUDED_ARCHS[sdk=iphonesimulator*]="
    + " ".join(part for part in match.group(1).split() if part != "arm64"),
    text,
    flags=re.MULTILINE,
)
path.write_text(text, encoding="utf-8")
PY
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
elif mode == "simctl-watchos":
    devices = payload.get("devices", {})
    for runtime, runtime_devices in sorted(devices.items()):
        if ".watchOS-" not in runtime:
            continue
        runtime_label = runtime.split(".watchOS-")[-1].replace("-", ".")
        for device in runtime_devices:
            if not device.get("isAvailable"):
                continue
            label = " | ".join(
                [
                    device.get("name", device.get("udid", "unknown")),
                    f"watchOS {runtime_label}",
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

get_watchos_simulator_entries() {
  local tmp
  tmp="$(make_temp_json simctl-watchos-devices)"
  xcrun simctl list devices available --json > "$tmp"
  json_to_entries "simctl-watchos" "$tmp"
  rm -f "$tmp"
}

find_paired_watch_simulator() {
  local ios_udid="$1"
  local tmp result
  tmp="$(make_temp_json simctl-pairs)"
  xcrun simctl list pairs --json > "$tmp" 2>/dev/null || { rm -f "$tmp"; return; }
  result="$(/usr/bin/python3 - "$tmp" "$ios_udid" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
    target = sys.argv[2]
    for pair in data.get("pairs", {}).values():
        phone = pair.get("phone", {})
        watch = pair.get("watch", {})
        if phone.get("udid") == target and watch.get("isAvailable", False):
            print(watch.get("udid", ""))
            break
except Exception:
    pass
PY
  )"
  rm -f "$tmp"
  printf '%s' "$result"
}

sim_pair_failure() {
  local phone_udid="${1:-}"
  local watch_udid="${2:-}"
  log "[sim-pair] Pairing failed."
  log "[sim-pair] Chosen iPhone UDID: ${phone_udid:-unknown}"
  log "[sim-pair] Chosen Watch UDID: ${watch_udid:-unknown}"
  log ""
  log "[sim-pair] xcrun simctl list devices:"
  xcrun simctl list devices || true
  log ""
  log "[sim-pair] xcrun simctl list pairs:"
  xcrun simctl list pairs || true
  log ""
  log "[sim-pair] Suggested cleanup/repair:"
  log "  xcrun simctl shutdown all"
  log "  xcrun simctl delete unavailable"
  log "  Then recreate a paired simulator in Xcode > Window > Devices and Simulators > Simulators."
  exit 1
}

simctl_json_available_or_fallback() {
  local section="$1"
  local output_file="$2"
  if xcrun simctl list -j "$section" > "$output_file" 2>/dev/null; then
    return 0
  fi
  log "[sim-pair] Warning: simctl JSON output failed for '$section'. Text output follows:"
  xcrun simctl list "$section" || true
  return 1
}

list_available_ios_simulators() {
  local tmp
  tmp="$(make_temp_json simctl-ios-devices)"
  simctl_json_available_or_fallback devices "$tmp" || { rm -f "$tmp"; return 1; }
  json_to_entries "simctl" "$tmp"
  rm -f "$tmp"
}

list_available_watch_simulators() {
  local tmp
  tmp="$(make_temp_json simctl-watch-devices)"
  simctl_json_available_or_fallback devices "$tmp" || { rm -f "$tmp"; return 1; }
  json_to_entries "simctl-watchos" "$tmp"
  rm -f "$tmp"
}

get_booted_ios_simulator_udid() {
  local tmp
  tmp="$(make_temp_json simctl-booted-ios)"
  simctl_json_available_or_fallback devices "$tmp" || { rm -f "$tmp"; return; }
  /usr/bin/python3 - "$tmp" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    payload = json.load(fh)
for runtime, devices in payload.get("devices", {}).items():
    if ".iOS-" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("state") == "Booted":
            print(device.get("udid", ""))
            raise SystemExit
PY
  rm -f "$tmp"
}

get_booted_watch_simulator_udid() {
  local tmp
  tmp="$(make_temp_json simctl-booted-watch)"
  simctl_json_available_or_fallback devices "$tmp" || { rm -f "$tmp"; return; }
  /usr/bin/python3 - "$tmp" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    payload = json.load(fh)
for runtime, devices in payload.get("devices", {}).items():
    if ".watchOS-" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("state") == "Booted":
            print(device.get("udid", ""))
            raise SystemExit
PY
  rm -f "$tmp"
}

get_existing_simulator_pairs() {
  local tmp
  tmp="$(make_temp_json simctl-pairs)"
  xcrun simctl list pairs --json > "$tmp" 2>/dev/null || { rm -f "$tmp"; return; }
  /usr/bin/python3 - "$tmp" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    payload = json.load(fh)
for pair_id, pair in payload.get("pairs", {}).items():
    phone = pair.get("phone", {})
    watch = pair.get("watch", {})
    if phone.get("isAvailable") is False or watch.get("isAvailable") is False:
        continue
    print(f"{pair_id}|||{phone.get('udid', '')}|||{watch.get('udid', '')}")
PY
  rm -f "$tmp"
}

find_pair_for_phone_or_watch() {
  local phone_udid="${1:-}"
  local watch_udid="${2:-}"
  get_existing_simulator_pairs | awk -F '\\|\\|\\|' -v phone="$phone_udid" -v watch="$watch_udid" '
    (phone == "" || $2 == phone) && (watch == "" || $3 == watch) { print; exit }
  '
}

ensure_paired_simulators() {
  local preferred_phone_udid="${1:-}"
  local preferred_phone_name="${2:-}"

  [[ -x /usr/bin/python3 ]] || die "Missing required command: /usr/bin/python3 (needed to parse simctl JSON; jq is not required)."
  require_cmd xcrun

  local tmp_output
  tmp_output="$(make_temp_json sim-pair-output)"
  if ! /usr/bin/python3 - "${SIM_PAIR_DRY_RUN:-0}" "$preferred_phone_udid" "$preferred_phone_name" > "$tmp_output" <<'PY'
import json
import re
import subprocess
import sys

dry_run = sys.argv[1] == "1"
preferred_phone_udid = sys.argv[2]
preferred_phone_name = sys.argv[3]
iphone_prefs = ["iPhone 16 Pro", "iPhone 15 Pro", "iPhone 14 Pro", "iPhone 13"]
watch_prefs = ["Apple Watch Series 10", "Apple Watch Series 9", "Apple Watch Ultra 2", "Apple Watch Series 8"]

def simctl_json(*args):
    proc = subprocess.run(["xcrun", "simctl", "list", "-j", *args], text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or f"simctl list -j {' '.join(args)} failed")
    return json.loads(proc.stdout)

def version_tuple(item):
    version = str(item.get("version") or item.get("name") or "")
    nums = [int(part) for part in re.findall(r"\d+", version)]
    return tuple(nums)

def newest_runtime(runtimes, platform_name):
    candidates = [
        runtime for runtime in runtimes.get("runtimes", [])
        if runtime.get("isAvailable")
        and (runtime.get("platform") == platform_name or f".{platform_name}-" in runtime.get("identifier", ""))
    ]
    if not candidates:
        raise SystemExit(f"No available {platform_name} simulator runtime is installed.")
    return sorted(candidates, key=version_tuple, reverse=True)[0]

def preferred_devicetype(devicetypes, product, prefs):
    candidates = [
        dt for dt in devicetypes.get("devicetypes", [])
        if product in dt.get("name", "") and dt.get("identifier")
    ]
    if not candidates:
        raise SystemExit(f"No available {product} simulator device type is installed.")
    for pref in prefs:
        for dt in candidates:
            if pref in dt.get("name", ""):
                return dt
    return candidates[0]

def all_devices(devices_payload, runtime_fragment):
    result = []
    for runtime, devices in devices_payload.get("devices", {}).items():
        if runtime_fragment not in runtime:
            continue
        for device in devices:
            if device.get("isAvailable"):
                item = dict(device)
                item["runtime"] = runtime
                result.append(item)
    return result

def pairs_payload():
    proc = subprocess.run(["xcrun", "simctl", "list", "pairs", "--json"], text=True, capture_output=True)
    if proc.returncode != 0:
        return {}
    return json.loads(proc.stdout).get("pairs", {})

def available_pairs(pairs):
    result = []
    for pair_id, pair in pairs.items():
        phone = pair.get("phone", {})
        watch = pair.get("watch", {})
        if phone.get("udid") and watch.get("udid") and phone.get("isAvailable", True) and watch.get("isAvailable", True):
            result.append((pair_id, phone.get("udid"), watch.get("udid")))
    return result

def paired_watch_udids(pairs):
    return {watch_udid for _, _, watch_udid in available_pairs(pairs)}

def pair_for_phone(pairs, phone_udid):
    for pair_id, phone_udid_candidate, watch_udid in available_pairs(pairs):
        if phone_udid_candidate == phone_udid:
            return pair_id, phone_udid_candidate, watch_udid
    return None

def pair_for_phone_and_watch(pairs, phone_udid, watch_udid):
    for pair_id, phone_udid_candidate, watch_udid_candidate in available_pairs(pairs):
        if phone_udid_candidate == phone_udid and watch_udid_candidate == watch_udid:
            return pair_id, phone_udid_candidate, watch_udid_candidate
    return None

def device_by_udid(devices, udid):
    for device in devices:
        if device.get("udid") == udid:
            return device
    return None

def choose_existing_phone(phones, pairs):
    if preferred_phone_udid:
        phone = device_by_udid(phones, preferred_phone_udid)
        if not phone:
            raise SystemExit(f"Selected iPhone simulator is not available: {preferred_phone_udid}")
        return phone, "selected iPhone"
    booted = [phone for phone in phones if phone.get("state") == "Booted"]
    for phone in booted:
        if pair_for_phone(pairs, phone.get("udid")):
            return phone, "booted paired iPhone"
    for _, phone_udid, _ in available_pairs(pairs):
        phone = device_by_udid(phones, phone_udid)
        if phone:
            return phone, "existing pair"
    if booted:
        return booted[0], "booted iPhone"
    return (phones[0], "available iPhone") if phones else (None, "")

def choose_watch_for_phone(watches, pairs, phone_udid):
    existing_pair = pair_for_phone(pairs, phone_udid)
    if existing_pair:
        watch = device_by_udid(watches, existing_pair[2])
        if watch:
            return watch, existing_pair[0], "existing pair"
    booted = [watch for watch in watches if watch.get("state") == "Booted"]
    for watch in booted:
        existing = pair_for_phone_and_watch(pairs, phone_udid, watch.get("udid"))
        if existing:
            return watch, existing[0], "booted paired Watch"
    paired_watches = paired_watch_udids(pairs)
    unpaired = [watch for watch in watches if watch.get("udid") not in paired_watches]
    return (unpaired[0], "", "available unpaired Watch") if unpaired else (None, "", "")

def create_device(name, devicetype_id, runtime_id):
    if dry_run:
        return f"DRY-RUN-{re.sub('[^A-Za-z0-9]+', '-', name).strip('-')}"
    proc = subprocess.run(["xcrun", "simctl", "create", name, devicetype_id, runtime_id], text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or f"Could not create simulator {name}")
    return proc.stdout.strip().splitlines()[-1].strip()

def emit_selection(phone, watch, phone_reason, watch_reason, pair_id, created_phone, created_watch, created_pair):
    print(f"PHONE_NAME|||{phone.get('name', '')}", flush=True)
    print(f"PHONE_UDID|||{phone.get('udid', '')}", flush=True)
    print(f"PHONE_REASON|||{phone_reason}", flush=True)
    print(f"WATCH_NAME|||{watch.get('name', '')}", flush=True)
    print(f"WATCH_UDID|||{watch.get('udid', '')}", flush=True)
    print(f"WATCH_REASON|||{watch_reason}", flush=True)
    print(f"PAIR_ID|||{pair_id}", flush=True)
    print(f"CREATED_PHONE|||{int(created_phone)}", flush=True)
    print(f"CREATED_WATCH|||{int(created_watch)}", flush=True)
    print(f"CREATED_PAIR|||{int(created_pair)}", flush=True)

def create_pair(watch, phone, phone_reason, watch_reason, created_phone, created_watch):
    if dry_run:
        return "DRY-RUN-PAIR"
    proc = subprocess.run(["xcrun", "simctl", "pair", watch["udid"], phone["udid"]], text=True, capture_output=True)
    if proc.returncode != 0:
        emit_selection(phone, watch, phone_reason, watch_reason, "", created_phone, created_watch, False)
        raise SystemExit(proc.stderr.strip() or "Could not pair simulators")
    pairs = pairs_payload()
    found = pair_for_phone_and_watch(pairs, phone["udid"], watch["udid"])
    return found[0] if found else proc.stdout.strip().splitlines()[-1].strip()

devices_payload = simctl_json("devices")
runtimes_payload = simctl_json("runtimes")
devicetypes_payload = simctl_json("devicetypes")
pairs = pairs_payload()

phones = all_devices(devices_payload, ".iOS-")
watches = all_devices(devices_payload, ".watchOS-")

created_phone = False
created_watch = False
created_pair = False

phone, phone_reason = choose_existing_phone(phones, pairs)
if not phone:
    runtime = newest_runtime(runtimes_payload, "iOS")
    devicetype = preferred_devicetype(devicetypes_payload, "iPhone", iphone_prefs)
    phone = {
        "name": f"SDAL {devicetype['name']}",
        "udid": create_device(f"SDAL {devicetype['name']}", devicetype["identifier"], runtime["identifier"]),
        "state": "Shutdown",
    }
    phones.append(phone)
    created_phone = True
    phone_reason = f"created with {runtime.get('name', runtime['identifier'])}"

watch, pair_id, watch_reason = choose_watch_for_phone(watches, pairs, phone["udid"])
if not watch:
    runtime = newest_runtime(runtimes_payload, "watchOS")
    devicetype = preferred_devicetype(devicetypes_payload, "Apple Watch", watch_prefs)
    watch = {
        "name": f"SDAL {devicetype['name']}",
        "udid": create_device(f"SDAL {devicetype['name']}", devicetype["identifier"], runtime["identifier"]),
        "state": "Shutdown",
    }
    watches.append(watch)
    created_watch = True
    watch_reason = f"created with {runtime.get('name', runtime['identifier'])}"

if not pair_id:
    pair_id = create_pair(watch, phone, phone_reason, watch_reason, created_phone, created_watch)
    created_pair = True

emit_selection(phone, watch, phone_reason, watch_reason, pair_id, created_phone, created_watch, created_pair)
PY
  then
    local phone_for_diag="" watch_for_diag=""
    phone_for_diag="$(awk -F '\\|\\|\\|' '$1 == "PHONE_UDID" {print $2; exit}' "$tmp_output" 2>/dev/null || true)"
    watch_for_diag="$(awk -F '\\|\\|\\|' '$1 == "WATCH_UDID" {print $2; exit}' "$tmp_output" 2>/dev/null || true)"
    rm -f "$tmp_output"
    sim_pair_failure "$phone_for_diag" "$watch_for_diag"
  fi

  SIM_PAIR_PHONE_NAME=""
  SIM_PAIR_PHONE_UDID=""
  SIM_PAIR_WATCH_NAME=""
  SIM_PAIR_WATCH_UDID=""
  SIM_PAIR_ID=""
  local line key value created_pair="0"
  while IFS= read -r line; do
    key="${line%%|||*}"
    value="${line#*|||}"
    case "$key" in
      PHONE_NAME) SIM_PAIR_PHONE_NAME="$value" ;;
      PHONE_UDID) SIM_PAIR_PHONE_UDID="$value" ;;
      PHONE_REASON) log "[sim-pair] iPhone selection: $value" ;;
      WATCH_NAME) SIM_PAIR_WATCH_NAME="$value" ;;
      WATCH_UDID) SIM_PAIR_WATCH_UDID="$value" ;;
      WATCH_REASON) log "[sim-pair] Watch selection: $value" ;;
      PAIR_ID) SIM_PAIR_ID="$value" ;;
      CREATED_PHONE) [[ "$value" == "1" ]] && log "[sim-pair] Created new iPhone simulator." ;;
      CREATED_WATCH) [[ "$value" == "1" ]] && log "[sim-pair] Created new Apple Watch simulator." ;;
      CREATED_PAIR) created_pair="$value" ;;
    esac
  done < "$tmp_output"
  rm -f "$tmp_output"

  [[ -n "$SIM_PAIR_PHONE_UDID" && -n "$SIM_PAIR_WATCH_UDID" ]] \
    || sim_pair_failure "$SIM_PAIR_PHONE_UDID" "$SIM_PAIR_WATCH_UDID"

  if [[ "$created_pair" == "1" ]]; then
    log "[sim-pair] Created new pair: $SIM_PAIR_ID"
  elif [[ -n "$SIM_PAIR_ID" ]]; then
    log "[sim-pair] Existing pair found: $SIM_PAIR_ID"
  fi
  log "[sim-pair] Selected iPhone: $SIM_PAIR_PHONE_NAME ($SIM_PAIR_PHONE_UDID)"
  log "[sim-pair] Selected Watch: $SIM_PAIR_WATCH_NAME ($SIM_PAIR_WATCH_UDID)"
}

get_flutter_ios_device_id() {
  local simctl_udid="$1"
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" devices --machine 2>/dev/null | grep -o '"id":"[^"]*"' | grep -i simulator | head -1 | sed 's/"id":"\([^"]*\)"/\1/'
  ) || echo "$simctl_udid"
}

install_ios_simulator_only() {
  local iphone_udid="$1"
  local build_mode="$2"

  apply_app_version_update
  open -a Simulator >/dev/null 2>&1 || true
  boot_simulator_if_needed "$iphone_udid"
  wait_for_simulator_boot "$iphone_udid"
  ensure_xcode_can_target_ios_simulator "$iphone_udid"
  uninstall_ios_simulator_app_if_requested "$iphone_udid"
  ensure_flutter_build_dir_override
  prepare_ios
  patch_generated_xcconfig_for_ios_simulator
  build_ios_simulator_runner_app "$iphone_udid" "$build_mode"

  local ios_app_path
  ios_app_path="$(find_ios_simulator_runner_app)"

  log ""
  log "Starting Flutter with pre-built app. Press q to quit."
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" run -d "$iphone_udid" --"$build_mode" \
      --use-application-binary "$ios_app_path" || true
  )
}

boot_simulator_if_needed() {
  local udid="$1"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
}

wait_for_simulator_boot() {
  local udid="$1"
  if xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then
    return 0
  fi

  local attempts=60 state
  while (( attempts > 0 )); do
    state="$(xcrun simctl list devices "$udid" 2>/dev/null | awk -F '[()]' '/Booted/{print "Booted"; exit}')"
    if [[ "$state" == "Booted" ]]; then
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 2
  done
  die "Simulator did not boot: $udid"
}

ensure_xcode_can_target_ios_simulator() {
  local udid="$1"
  local attempts=20 destinations
  while (( attempts > 0 )); do
    destinations="$(
      xcodebuild \
        -workspace "$IOS_DIR/Runner.xcworkspace" \
        -scheme Runner \
        -showdestinations 2>/dev/null || true
    )"
    if grep -q "id:$udid" <<<"$destinations"; then
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 1
  done

  log "Xcode cannot target the selected simulator yet: $udid"
  log "Current Xcode destinations:"
  xcodebuild -workspace "$IOS_DIR/Runner.xcworkspace" -scheme Runner -showdestinations 2>&1 || true
  die "Selected iOS simulator is visible to simctl but not to Xcode. Try running option 2 again after Simulator finishes booting."
}

activate_simulator_pair_if_supported() {
  local pair_identifier="$1"
  if [[ -z "$pair_identifier" ]]; then
    log "[sim-pair] Warning: pair identifier could not be determined; skipping pair_activate."
    return 0
  fi
  if xcrun simctl pair_activate "$pair_identifier" >/dev/null 2>&1; then
    log "[sim-pair] Activated pair: $pair_identifier"
  else
    log "[sim-pair] Warning: simctl pair_activate failed or is not supported; continuing with the existing pair."
  fi
}

find_ios_simulator_runner_app() {
  local candidates=(
    "$IOS_SIMULATOR_BUILD_DIR_ABS/Build/Products/Debug-iphonesimulator/Runner.app"
    "$ROOT_DIR/build/ios/iphonesimulator/Runner.app"
    "$ROOT_DIR/$FLUTTER_BUILD_DIR_REL/ios/iphonesimulator/Runner.app"
    "$HOME/Library/Caches/flutter_sdal_flutter_build/ios/iphonesimulator/Runner.app"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done
  find "$ROOT_DIR/build" "$HOME/Library/Caches/flutter_sdal_flutter_build" \
    -path '*/ios/iphonesimulator/Runner.app' -type d 2>/dev/null | head -1 || true
}

build_ios_simulator_runner_app() {
  local iphone_udid="$1"
  local build_mode="$2"
  [[ "$build_mode" == "debug" ]] \
    || die "Only Debug builds are supported on iOS Simulator."

  disable_runner_watch_embed_for_ios_simulator
  log "Building Runner.app for iOS Simulator with Xcode..."
  (
    cd "$ROOT_DIR"
    xcodebuild \
      -workspace ios/Runner.xcworkspace \
      -scheme Runner \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination "platform=iOS Simulator,id=$iphone_udid" \
      -derivedDataPath "$IOS_SIMULATOR_BUILD_DIR_ABS" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      build
  )
}

install_and_launch_ios_simulator_runner_app() {
  local iphone_udid="$1"
  local ios_app_path
  ios_app_path="$(find_ios_simulator_runner_app)"
  [[ -n "$ios_app_path" && -d "$ios_app_path" ]] \
    || die "Runner.app not found after iOS Simulator build."

  log "Installing Runner.app to simulator $iphone_udid..."
  xcrun simctl terminate "$iphone_udid" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$iphone_udid" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$iphone_udid" "$ios_app_path"
  xcrun simctl launch "$iphone_udid" "$IOS_BUNDLE_ID"
}

install_ios_app_to_paired_phone() {
  local iphone_udid="$1"
  local build_mode="$2"
  log "[sim-pair] Installing iOS app to paired iPhone..."
  if [[ "${SIM_PAIR_DRY_RUN:-0}" == "1" ]]; then
    log "[sim-pair] Dry run: skipping Flutter simulator build/install for $iphone_udid."
    return 0
  fi

  [[ -n "$SIM_PAIR_WATCH_APP_PATH" && -d "$SIM_PAIR_WATCH_APP_PATH" ]] \
    || die "SdalWatch.app must be built before installing the paired iPhone app."

  patch_generated_xcconfig_for_ios_simulator
  build_ios_simulator_runner_app "$iphone_udid" "$build_mode"

  local ios_app_path
  ios_app_path="$(find_ios_simulator_runner_app)"
  [[ -n "$ios_app_path" && -d "$ios_app_path" ]] \
    || die "Runner.app not found after Flutter simulator build."

  log "[sim-pair] Embedding SdalWatch.app into Runner.app for WatchConnectivity."
  rm -rf "$ios_app_path/Watch"
  mkdir -p "$ios_app_path/Watch"
  cp -R "$SIM_PAIR_WATCH_APP_PATH" "$ios_app_path/Watch/SdalWatch.app"

  log "[sim-pair] Runner.app: $ios_app_path"
  xcrun simctl terminate "$iphone_udid" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$iphone_udid" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$iphone_udid" "$ios_app_path"
  xcrun simctl launch "$iphone_udid" "$IOS_BUNDLE_ID"
}

install_watch_app_to_paired_watch() {
  local watch_udid="$1"
  log "[sim-pair] Installing watchOS app to paired Watch..."
  if [[ "${SIM_PAIR_DRY_RUN:-0}" == "1" ]]; then
    log "[sim-pair] Dry run: skipping watchOS install/launch for $watch_udid."
    return 0
  fi
  build_install_watch_simulator "$watch_udid"
}

start_sim_pair_logs() {
  local iphone_udid="$1"
  local watch_udid="$2"

  if [[ "${SIM_PAIR_DRY_RUN:-0}" == "1" ]]; then
    log "[sim-pair] Dry run: skipping logs."
    return 0
  fi
  if [[ "${SIM_PAIR_AUTO_LOGS:-1}" != "1" ]]; then
    log "[sim-pair] Auto logs disabled (SIM_PAIR_AUTO_LOGS=$SIM_PAIR_AUTO_LOGS)."
    return 0
  fi

  trap cleanup EXIT

  if [[ "${SIM_PAIR_WATCH_LOGS:-0}" == "1" ]]; then
    log ""
    log "[sim-pair] Starting watchOS logs for SdalWatch and WatchConnectivity..."
    xcrun simctl spawn "$watch_udid" log stream \
      --style compact \
      --level debug \
      --predicate 'process == "SdalWatch" OR subsystem CONTAINS "WatchConnectivity" OR composedMessage CONTAINS "WCSession" OR composedMessage CONTAINS "SdalWatch"' &
    SIM_PAIR_WATCH_LOG_PID=$!
  fi

  log ""
  log "[sim-pair] Starting Flutter logs with flutter attach."
  log "[sim-pair] Press q in flutter attach to quit."
  (
    cd "$ROOT_DIR"
    "$FLUTTER_BIN" attach -d "$iphone_udid" || true
  )
  return 0
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

resign_ios_release_app_for_device_install() {
  local app_path="$1"
  local xcent_path="$2"
  local sign_sha framework watch_app_path watch_xcent_path

  [[ -d "$app_path" ]] || die "Runner.app not found after build: $app_path"
  [[ -f "$xcent_path" ]] || die "Missing entitlements file: $xcent_path"

  sign_sha="$(resolve_signing_identity_sha)"

  log "Re-signing embedded frameworks with $sign_sha."
  while IFS= read -r framework; do
    codesign --force --sign "$sign_sha" --timestamp=none "$framework"
  done < <(find "$app_path/Frameworks" -maxdepth 1 -type d -name '*.framework' | sort)

  watch_app_path="$app_path/Watch/SdalWatch.app"
  watch_xcent_path="$IOS_RELEASE_BUILD_DIR_ABS/Runner.build/Release-watchos/SdalWatch.build/SdalWatch.app.xcent"
  if [[ -d "$watch_app_path" ]]; then
    [[ -f "$watch_xcent_path" ]] || die "Missing Watch entitlements file: $watch_xcent_path"

    log "Re-signing embedded Watch app."
    if [[ -d "$watch_app_path/Frameworks" ]]; then
      while IFS= read -r framework; do
        codesign --force --sign "$sign_sha" --timestamp=none "$framework"
      done < <(find "$watch_app_path/Frameworks" -maxdepth 1 -type d -name '*.framework' | sort)
    fi

    codesign \
      --force \
      --sign "$sign_sha" \
      --entitlements "$watch_xcent_path" \
      --timestamp=none \
      --generate-entitlement-der \
      "$watch_app_path"
  fi

  log "Re-signing app bundle."
  codesign \
    --force \
    --sign "$sign_sha" \
    --entitlements "$xcent_path" \
    --timestamp=none \
    --generate-entitlement-der \
    "$app_path"
}

build_sign_install_launch_ios_release() {
  local device_identifier="$1"
  local app_path xcent_path

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

  app_path="$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app"
  xcent_path="$IOS_RELEASE_BUILD_DIR_ABS/Runner.build/Release-iphoneos/Runner.build/Runner.app.xcent"
  resign_ios_release_app_for_device_install "$app_path" "$xcent_path"

  log "Installing release app on device."
  xcrun devicectl device install app \
    --device "$device_identifier" \
    "$app_path"

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
  log "Archive: $archive_path"
  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options_plist" \
    -allowProvisioningUpdates \
  || die "Export failed. Check xcodebuild output above."

  local ipa_path
  ipa_path="$(find "$export_path" -name '*.ipa' | head -1 || true)"
  [[ -f "$ipa_path" ]] || die "IPA not found after export in: $export_path"
  log "IPA: $ipa_path"

  log_testflight_signing_summary "$ipa_path"

  local version current_build last_build release_notes release_notes_file
  init_testflight_state
  version=$(grep "^version:" "$ROOT_DIR/pubspec.yaml" | sed 's/.*: //' | sed 's/+.*//')
  current_build=$(get_current_build_number "$ROOT_DIR")
  last_build=$(get_last_testflight_build)

  log ""
  log "Generating release notes..."
  log "  Current build: $current_build"
  log "  Last uploaded build: $last_build"

  if [[ "$current_build" == "$last_build" ]]; then
    log "  WARNING: Build number unchanged. Did you bump the version?"
    read -r -p "Continue anyway? [y/N] " confirm < /dev/tty
    [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
  fi

  release_notes=$(generate_release_notes "$ROOT_DIR" "$last_build" "HEAD")
  release_notes=$(format_release_notes "$version" "$current_build" "$release_notes")
  release_notes_file="$IOS_ARCHIVE_DIR/release_notes_${current_build}.txt"
  save_release_notes "$release_notes" "$release_notes_file"
  display_release_notes "$release_notes"

  log ""
  log "Step 3/3: Uploading to App Store Connect / TestFlight..."
  log "IPA: $ipa_path"
  log "(Upload may take several minutes depending on app size)"
  xcrun altool \
    --upload-app \
    -f "$ipa_path" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
  || die "Upload failed. Check xcrun altool output above."

  save_testflight_build_number "$current_build"

  log ""
  log "Upload complete!"
  log ""
  log "Next steps:"
  log "  1. Go to: https://appstoreconnect.apple.com → Your App → TestFlight"
  log "  2. Wait for Apple to finish processing (typically 15–30 minutes)"
  log "  3. The build will appear under 'iOS Builds'"
  log "  4. Edit the build details and add the release notes:"
  log "     📋 Release notes file: $release_notes_file"
  log "  5. Add internal or external testers as needed"
  log ""
  log "Artifacts saved at:"
  log "  Archive       : $archive_path"
  log "  IPA           : $ipa_path"
  log "  Release notes : $release_notes_file"
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
      ${extra_args[@]+"${extra_args[@]}"}
  ) >&2

  local app_path
  app_path="$(find "$watch_build_dir" -maxdepth 4 -name 'SdalWatch.app' \
    ! -path '*/SdalWatch.app/*' 2>/dev/null | head -1 || true)"
  printf '%s' "$app_path"
}

build_install_watch_simulator() {
  local watch_sim_udid="$1"

  log "Building SdalWatch for watchOS Simulator (Debug)..."
  local watch_app_path
  watch_app_path="$(build_watch_app_for_sdk "watchsimulator" "Debug")"
  [[ -n "$watch_app_path" && -d "$watch_app_path" ]] \
    || die "SdalWatch build for watchsimulator failed — app bundle not found."
  SIM_PAIR_WATCH_APP_PATH="$watch_app_path"

  log "SdalWatch build output: $watch_app_path"
  log "Removing existing SdalWatch from watchOS Simulator, if present..."
  xcrun simctl terminate "$watch_sim_udid" "$WATCH_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$watch_sim_udid" "$WATCH_BUNDLE_ID" >/dev/null 2>&1 || true

  log "Installing SdalWatch on watchOS Simulator ($watch_sim_udid)..."
  xcrun simctl install "$watch_sim_udid" "$watch_app_path"
  log "Launching SdalWatch on watchOS Simulator..."
  xcrun simctl launch "$watch_sim_udid" "$WATCH_BUNDLE_ID" >/dev/null 2>&1 || true
  log "SdalWatch installed and launched on watchOS Simulator."
}

build_install_ios_and_watch() {
  local iphone_identifier="$1"
  iphone_identifier="$(trim "$iphone_identifier")"
  [[ -n "$iphone_identifier" ]] || die "No iPhone identifier selected for Apple Watch install."

  prepare_ios

  # SdalWatch is now embedded via "Embed Watch Content" Xcode build phase.
  # One workspace build produces Runner.app with SdalWatch.app inside Watch/.
  # Build for the selected iPhone so Xcode can refresh development
  # provisioning for the paired Apple Watch as well.

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
      -destination "id=$iphone_identifier" \
      FLUTTER_SUPPRESS_ANALYTICS=true \
      COMPILER_INDEX_STORE_ENABLE=NO \
      build
  )

  local ios_app_path="$IOS_RELEASE_BUILD_DIR_ABS/Release-iphoneos/Runner.app"
  local xcent_path="$IOS_RELEASE_BUILD_DIR_ABS/Runner.build/Release-iphoneos/Runner.build/Runner.app.xcent"
  resign_ios_release_app_for_device_install "$ios_app_path" "$xcent_path"

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
  runner_app_in_archive="$(find "$archive_path/Products/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
  watch_in_archive="$(find "${runner_app_in_archive:-__missing__}/Watch" -name 'SdalWatch.app' 2>/dev/null | head -1 || true)"
  if [[ -n "$watch_in_archive" ]]; then
    log "Watch app verified in archive: $watch_in_archive"
  else
    log "[WARN] SdalWatch.app not found in archive — Watch may not deploy to Apple Watch."
  fi

  log ""
  log "Step 2/3: Exporting IPA from archive..."
  log "Archive: $archive_path"
  xcodebuild \
    -exportArchive \
    -archivePath "$archive_path" \
    -exportPath "$export_path" \
    -exportOptionsPlist "$export_options_plist" \
    -allowProvisioningUpdates \
  || die "Export failed. Check xcodebuild output above."

  local ipa_path
  ipa_path="$(find "$export_path" -name '*.ipa' | head -1 || true)"
  [[ -f "$ipa_path" ]] || die "IPA not found after export in: $export_path"
  log "IPA: $ipa_path"

  # Verify Watch app made it into the IPA
  local watch_in_ipa
  watch_in_ipa="$(unzip -l "$ipa_path" 2>/dev/null | grep -c 'SdalWatch' || true)"
  if [[ "$watch_in_ipa" -gt 0 ]]; then
    log "Watch app verified in IPA ($watch_in_ipa files)"
  else
    log "[WARN] SdalWatch not found inside IPA — Watch companion app will NOT be distributed."
  fi

  log_testflight_signing_summary "$ipa_path"

  local version current_build last_build release_notes release_notes_file
  init_testflight_state
  version=$(grep "^version:" "$ROOT_DIR/pubspec.yaml" | sed 's/.*: //' | sed 's/+.*//')
  current_build=$(get_current_build_number "$ROOT_DIR")
  last_build=$(get_last_testflight_build)

  log ""
  log "Generating release notes..."
  log "  Current build: $current_build"
  log "  Last uploaded build: $last_build"

  if [[ "$current_build" == "$last_build" ]]; then
    log "  WARNING: Build number unchanged. Did you bump the version?"
    read -r -p "Continue anyway? [y/N] " confirm < /dev/tty
    [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
  fi

  release_notes=$(generate_release_notes "$ROOT_DIR" "$last_build" "HEAD")
  release_notes=$(format_release_notes "$version" "$current_build" "$release_notes")
  release_notes_file="$IOS_ARCHIVE_DIR/release_notes_${current_build}.txt"
  save_release_notes "$release_notes" "$release_notes_file"
  display_release_notes "$release_notes"

  log ""
  log "Step 3/3: Uploading to App Store Connect / TestFlight..."
  log "IPA: $ipa_path"
  log "(Upload may take several minutes depending on app size)"
  xcrun altool \
    --upload-app \
    -f "$ipa_path" \
    -t ios \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" \
  || die "Upload failed. Check xcrun altool output above."

  save_testflight_build_number "$current_build"

  log ""
  log "Done!"
  log ""
  log "Next steps:"
  log "  1. Go to: https://appstoreconnect.apple.com -> Your App -> TestFlight"
  log "  2. Wait for Apple to finish processing (typically 15-30 minutes)"
  log "  3. The build will appear under 'iOS Builds'"
  log "  4. Edit the build details and add the release notes:"
  log "     📋 Release notes file: $release_notes_file"
  log "  5. SdalWatch is embedded — iPhone auto-deploys it to Apple Watch"
  log "  6. On Watch: open the App Store app or wait for auto-install"
  log ""
  log "Artifacts saved at:"
  log "  Archive       : $archive_path"
  log "  IPA           : $ipa_path"
  log "  Release notes : $release_notes_file"
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

      printf '\niOS Simulator mode\n'
      printf '  1. iOS only\n'
      printf '  2. iOS + Apple Watch\n'
      local simulator_mode
      simulator_mode="$(prompt_number 2 "Choose simulator mode: ")"

      load_entries get_ios_simulator_entries
      local selected label selected_iphone_udid
      selected="$(select_from_entries "Available iOS simulators" "${entries[@]}")"
      label="${selected%%|||*}"
      selected_iphone_udid="${selected##*|||}"
      log "Selected iOS simulator: $label"

      if [[ "$simulator_mode" == "1" ]]; then
        install_ios_simulator_only "$selected_iphone_udid" "$build_mode"
        return 0
      fi

      ensure_paired_simulators "$selected_iphone_udid" "$label"

      if [[ "${SIM_PAIR_DRY_RUN:-0}" == "1" ]]; then
        log "[sim-pair] Dry run: skipping version file update."
      else
        apply_app_version_update
      fi
      open -a Simulator >/dev/null 2>&1 || true
      if [[ "${SIM_PAIR_DRY_RUN:-0}" != "1" ]]; then
        log "[sim-pair] Booting iPhone..."
        boot_simulator_if_needed "$SIM_PAIR_PHONE_UDID"
        wait_for_simulator_boot "$SIM_PAIR_PHONE_UDID"
        log "[sim-pair] Booting Watch..."
        boot_simulator_if_needed "$SIM_PAIR_WATCH_UDID"
        wait_for_simulator_boot "$SIM_PAIR_WATCH_UDID"
        activate_simulator_pair_if_supported "$SIM_PAIR_ID"
      else
        log "[sim-pair] Dry run: skipping simulator boot and pair activation."
      fi

      if [[ "${SIM_PAIR_DRY_RUN:-0}" != "1" ]]; then
        uninstall_ios_simulator_app_if_requested "$SIM_PAIR_PHONE_UDID"
        ensure_flutter_build_dir_override
        prepare_ios
      else
        log "[sim-pair] Dry run: skipping build preparation and uninstall."
      fi

      install_watch_app_to_paired_watch "$SIM_PAIR_WATCH_UDID"
      install_ios_app_to_paired_phone "$SIM_PAIR_PHONE_UDID" "$build_mode"
      start_sim_pair_logs "$SIM_PAIR_PHONE_UDID" "$SIM_PAIR_WATCH_UDID"
      return 0
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
