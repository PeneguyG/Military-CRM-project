#!/bin/bash
# Run from any directory. FLUTTER may point to a Flutter executable with spaces.
set -euo pipefail
action="${1:-run}"
case "$action" in
  run|build|check) ;;
  *) echo "Usage: bash scripts/macos.sh [run|build|check] [Flutter options...]" >&2; exit 64 ;;
esac
if [ "$#" -gt 0 ]; then shift; fi
if [ "$(uname -s)" != Darwin ]; then
  echo "macOS builds require a Mac with Xcode. Use flutter run -d windows on Windows." >&2
  exit 1
fi
flutter="${FLUTTER:-flutter}"
if ! command -v "$flutter" >/dev/null 2>&1; then
  echo "Install Flutter, add its bin folder to PATH, or set FLUTTER to its executable." >&2
  exit 1
fi
xcodebuild -version
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/test_flutter"
"$flutter" pub get
case "$action" in
  run) exec "$flutter" run -d macos "$@" ;;
  check)
    "$flutter" analyze "$@"
    exec "$flutter" test
    ;;
  build)
    "$flutter" build macos --release "$@"
    app="build/macos/Build/Products/Release/Steel Wings CRM.app"
    # Check every Mach-O, including Flutter, plugins and SQLite native assets.
    # A universal launcher alone does not guarantee native support on both CPUs.
    found=0
    while IFS= read -r -d '' binary; do
      if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
        arches="$(/usr/bin/lipo -archs "$binary")"
        case " $arches " in *" arm64 "*) ;; *) echo "Missing arm64: $binary" >&2; exit 1 ;; esac
        case " $arches " in *" x86_64 "*) ;; *) echo "Missing x86_64: $binary" >&2; exit 1 ;; esac
        found=1
      fi
    done < <(find "$app" -type f -print0)
    if [ "$found" -ne 1 ]; then
      echo "No native binaries found in $app" >&2
      exit 1
    fi
    echo "Verified ARM64 and x86_64 native binaries: $app"
    ;;
esac
