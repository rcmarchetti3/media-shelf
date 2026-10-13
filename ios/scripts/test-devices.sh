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
  if xcodebuild test \
      -project MediaShelf.xcodeproj \
      -scheme MediaShelf \
      -destination "platform=iOS Simulator,name=$device" \
      -resultBundlePath "build/test-results/$slug.xcresult" \
      "${TARGET_FLAGS[@]}" \
      -quiet 2>&1 | grep -E "Test (Case|Suite).*(passed|failed)|error:|\*\* TEST" ; then
    echo "--- $device: passed"
  else
    echo "--- $device: FAILED"
    FAILED+=("$device")
  fi
done

echo
if (( ${#FAILED[@]} )); then
  echo "Failed on: ${(j:, :)FAILED}"
  exit 1
fi
echo "All devices passed."
