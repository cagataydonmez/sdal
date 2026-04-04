# flutter_sdal

Flutter iOS client for SDAL, built directly against the existing SDAL backend.

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
