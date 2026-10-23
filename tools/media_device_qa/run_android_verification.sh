#!/usr/bin/env bash
set -euo pipefail
# emulator-runner executes script lines separately. Keep the driver and all
# collector variables in this one shell so run-as always receives the package.
flutter drive --driver=test_driver/catalog_driver.dart --target=integration_test/catalog_device_test.dart --no-dds --keep-app-running -d emulator-5554
mkdir -p artifacts
package_id=$(python3 -c "import json; print(json.load(open('build/app/outputs/apk/debug/output-metadata.json'))['applicationId'])")
test -n "$package_id"
preview_dir=$(adb shell run-as "$package_id" find . -type d -name nimzo-drive-rendered | tr -d '\r')
test -n "$preview_dir"
adb exec-out run-as "$package_id" tar -C "$preview_dir" -c . > previews.tar
tar -xf previews.tar -C artifacts
python3 - <<'PY'
import json
from pathlib import Path
expected={r['id']+'.png' for folder in ['drive_catalog','drive_catalog_expanded','membership/remix','drive_catalog_premium'] for r in json.loads(Path('assets',folder,'manifest.json').read_text())['items']}
actual={p.name for p in Path('artifacts').glob('*.png')}
assert len(expected)==134 and actual==expected,(len(expected),len(actual))
assert all(p.stat().st_size>0 for p in Path('artifacts').glob('*.png'))
print('Collected all134 actual Android render previews; requested gift batch remains13 short')
PY
