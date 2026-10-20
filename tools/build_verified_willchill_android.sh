#!/usr/bin/env bash
# Safe local build: only with verified media, existing Vivox-enabled Android,
# and passing regression tests. Never publishes a public APK.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo 'REFUSING BUILD: supply the original local WillChill assets ZIP' >&2
  exit 2
fi
if [[ ! -f nimzo/FEATURES.lock.json || ! -f nimzo/pubspec.yaml ]]; then
  echo 'REFUSING BUILD: full NIMZO source is missing' >&2
  exit 2
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo 'REFUSING BUILD: Flutter SDK is not installed' >&2
  exit 2
fi
if [[ ! -f nimzo/android/app/src/main/java/io/nimzo/vivox/NimzoVivox.java ]]; then
  echo 'REFUSING BUILD: install canonical NIMZO native Vivox bridge first' >&2
  exit 2
fi
if [[ ! -f nimzo/android/app/libs/vivox-sdk-5.28.0.aar ]]; then
  echo 'REFUSING BUILD: verified Vivox 5.28.0 AAR missing' >&2
  exit 2
fi

python3 tools/import_willchill_package.py "$1"
python3 tools/verify_willchill_premium.py
cd nimzo
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release
cd ..
python3 tools/verify_willchill_apk_bundle.py nimzo/build/app/outputs/flutter-apk/app-release.apk

mkdir -p verified-premium-build
cp nimzo/build/app/outputs/flutter-apk/app-release.apk verified-premium-build/NIMZO_1.0.36_Premium_TEST.apk
sha256sum verified-premium-build/NIMZO_1.0.36_Premium_TEST.apk > verified-premium-build/SHA256SUMS.txt
echo 'Verified premium APK bundle. Native playback, room audio and signing identity still need device QA.'
