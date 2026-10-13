#!/usr/bin/env zsh
# Run the MediaShelf test suites on every current iPhone simulator.
#
# Usage:
#   scripts/test-devices.sh            # unit + UI tests on all devices below
#   scripts/test-devices.sh unit       # unit tests only (fast, one device is enough)
#   scripts/test-devices.sh ui         # UI tests only
#   DEVICES="iPhone 17,iPhone Duo" scripts/test-devices.sh ui
#
# Results land in build/test-results/<device>.xcresult. Open one with
# `xcrun xcresulttool get --path <file>` or in Xcode.
#
# The UI tests launch the app with --mock-server, so no backend is needed.

set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"
DEFAULT_DEVICES="iPhone Duo,iPhone 17,iPhone 17e,iPhone 18 Pro,iPhone 18 Pro Max,iPhone Air"
IFS=',' read -rA DEVICES <<< "${DEVICES:-$DEFAULT_DEVICES}"

case "$MODE" in
  unit) TARGET_FLAGS=(-only-testing:MediaShelfTests) ;;
  ui)   TARGET_FLAGS=(-only-testing:MediaShelfUITests) ;;
  all)  TARGET_FLAGS=() ;;
  *)    echo "unknown mode: $MODE (use unit, ui, or all)"; exit 2 ;;
esac

if [[ ! -d MediaShelf.xcodeproj ]]; then
  echo "No MediaShelf.xcodeproj; running xcodegen generate"
  xcodegen generate
fi

mkdir -p build/test-results
FAILED=()

for device in "${DEVICES[@]}"; do
  device="${device## }"
  slug="${device// /-}"
  echo
  echo "=== $device ($MODE) ==="
  rm -rf "build/test-results/$slug.xcresult"
  # Pass/fail comes from xcodebuild's own exit code. (Piping through grep made
  # a quiet, successful run look like a failure because grep matched nothing.)
  if xcodebuild test \
      -project MediaShelf.xcodeproj \
      -scheme MediaShelf \
      -destination "platform=iOS Simulator,name=$device" \
      -derivedDataPath build/DerivedData \
      -resultBundlePath "build/test-results/$slug.xcresult" \
      "${TARGET_FLAGS[@]}" \
      -quiet > "build/test-results/$slug.log" 2>&1; then
    outcome="passed"
  else
    outcome="FAILED"
    FAILED+=("$device")
  fi
  # One line of facts from the result bundle, whatever the exit code said.
  xcrun xcresulttool get test-results summary --path "build/test-results/$slug.xcresult" 2>/dev/null \
    | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('--- $device: $outcome | %s passed, %s failed, %s total' % (d.get('passedTests'), d.get('failedTests'), d.get('totalTestCount')))
    for f in d.get('testFailures', [])[:8]:
        print('    FAIL:', f.get('testName'), '|', (f.get('failureText') or '')[:140].replace(chr(10), ' '))
except Exception:
    print('--- $device: $outcome | no result bundle, see build/test-results/$slug.log')
"
done

echo
if (( ${#FAILED[@]} )); then
  echo "Failed on: ${(j:, :)FAILED}"
  exit 1
fi
echo "All devices passed."
