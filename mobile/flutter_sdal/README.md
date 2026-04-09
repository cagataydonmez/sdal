# flutter_sdal

Flutter iOS client for SDAL, built directly against the existing SDAL backend.

## Install / Run Matrix

| Target | Build | Recommended command | What it does |
| --- | --- | --- | --- |
| iPhone over cable or wireless | Debug | `./tool/install_local.sh` | Choose `iPhone` then `Debug`. Runs `flutter run` with a cache-backed build dir so device builds do not fail from Desktop/iCloud xattrs. |
| iPhone over cable or wireless | Release | `./tool/install_local.sh` | Choose `iPhone` then `Release`. Builds with `xcodebuild` into `~/Library/Caches`, re-signs embedded frameworks, installs, and launches automatically. |
| iOS Simulator | Debug | `./tool/install_local.sh` | Choose `iOS Simulator` then `Debug`. Opens Simulator, boots the selected device, and runs `flutter run --debug`. |
| iOS Simulator | Release | Not supported | Flutter does not support `--release` on iOS Simulator. Use `iPhone` + `Release`, or `iOS Simulator` + `Debug`. |
| Android Emulator | Debug | `./tool/install_local.sh` | Choose `Android Emulator` then `Debug`. Launches the selected emulator and runs `flutter run --debug`. |
| Android Emulator | Release | `./tool/install_local.sh` | Choose `Android Emulator` then `Release`. Launches the selected emulator and runs `flutter run --release`. |

## Direct Commands

| Target | Build | Direct command |
| --- | --- | --- |
| iPhone over cable or wireless | Debug | `flutter config --build-dir=../../../../Library/Caches/flutter_sdal_flutter_build && flutter run --debug -d <flutter-ios-device-id>` |
| iPhone over cable or wireless | Release | `cd ios && xcodebuild -configuration Release -allowProvisioningUpdates -allowProvisioningDeviceRegistration -workspace Runner.xcworkspace -scheme Runner BUILD_DIR=$HOME/Library/Caches/flutter_sdal_ios_build OBJROOT=$HOME/Library/Caches/flutter_sdal_ios_build -sdk iphoneos -destination generic/platform=iOS FLUTTER_SUPPRESS_ANALYTICS=true COMPILER_INDEX_STORE_ENABLE=NO` |
| iOS Simulator | Debug | `open -a Simulator && xcrun simctl boot <sim-udid> && flutter run --debug -d <sim-udid>` |
| iOS Simulator | Release | Not supported by Flutter on iOS Simulator |
| Android Emulator | Debug | `flutter emulators --launch <android-emulator-id> && flutter run --debug -d <android-device-id>` |
| Android Emulator | Release | `flutter emulators --launch <android-emulator-id> && flutter run --release -d <android-device-id>` |

## Local iOS Run Flow

1. Start the SDAL backend separately.
2. Make sure CocoaPods is installed and the target simulator exists.
3. Run the tracked helper:

```sh
./tool/run_ios_local.sh "iPhone 16 Pro 26.4"
```

The helper performs:

- `flutter pub get`
- `pod install`
- `flutter run`

It also exports `COPYFILE_DISABLE=1`, which avoids macOS metadata being copied into generated iOS frameworks during local simulator runs.

## Local iOS Release Build Flow

Use the tracked helper for a reproducible local release package without device signing:

```sh
./tool/build_ios_local.sh
```

The helper performs:

- `flutter pub get`
- `pod install`
- `flutter build ios --release --no-codesign`

It also exports `COPYFILE_DISABLE=1` so the same metadata-safe build path is used for release packaging.

## Environment overrides

You can override runtime configuration with `--dart-define`:

```sh
/Users/cagataydonmez/flutter/bin/flutter run \
  -d "iPhone 16 Pro 26.4" \
  --dart-define=SDAL_API_BASE_URL=https://example.com/api \
  --dart-define=SDAL_OAUTH_CALLBACK_SCHEME=sdalnative
```
