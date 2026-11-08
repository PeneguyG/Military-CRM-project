#!/bin/bash
# Build a self-contained Installer wizard. No scripts run on the recipient's Mac.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$(uname -s)" != Darwin ]; then echo 'Packaging requires macOS.' >&2; exit 1; fi
case "${1:-}" in
  '') bash "$root/scripts/macos.sh" build ;;
  --skip-build) ;;
  *) echo "Usage: bash scripts/package-macos.sh [--skip-build]" >&2; exit 64 ;;
esac
app="$root/test_flutter/build/macos/Build/Products/Release/Steel Wings CRM.app"
test -d "$app"
/usr/bin/codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
out="$root/dist/macos"
mkdir -p "$out"
stage="$(mktemp -d "${TMPDIR:-/tmp}/steel-wings-installer.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/payload/Applications" "$stage/resources"
ditto "$app" "$stage/payload/Applications/Steel Wings CRM.app"
cp "$root/installer/macos/Welcome.html" "$stage/resources/Welcome.html"
cp "$root/installer/macos/Finish.html" "$stage/resources/Finish.html"
# Keep the app in /Applications, even when another copy exists elsewhere.
pkgbuild --analyze --root "$stage/payload" "$stage/components.plist"
index=0
while /usr/libexec/PlistBuddy -c "Print :$index" "$stage/components.plist" >/dev/null 2>&1; do
  /usr/libexec/PlistBuddy -c "Set :$index:BundleIsRelocatable false" "$stage/components.plist"
  index=$((index + 1))
done
pkgbuild --root "$stage/payload" --component-plist "$stage/components.plist" \
  --identifier com.steelwings.crm.installer --version "$version" \
  --install-location / "$stage/CRM.pkg"
cat > "$stage/Distribution.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Steel Wings CRM</title>
  <welcome file="Welcome.html" mime-type="text/html"/>
  <conclusion file="Finish.html" mime-type="text/html"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <volume-check><allowed-os-versions><os-version min="12.0"/></allowed-os-versions></volume-check>
  <choices-outline><line choice="crm"/></choices-outline>
  <choice id="crm" visible="false" title="Steel Wings CRM"><pkg-ref id="com.steelwings.crm.installer"/></choice>
  <pkg-ref id="com.steelwings.crm.installer">CRM.pkg</pkg-ref>
</installer-gui-script>
XML
package="$out/Steel-Wings-CRM-$version.pkg"
if [ -n "${INSTALLER_SIGN_IDENTITY:-}" ]; then
  productbuild --distribution "$stage/Distribution.xml" --resources "$stage/resources" \
    --package-path "$stage" --sign "$INSTALLER_SIGN_IDENTITY" "$package"
else
  productbuild --distribution "$stage/Distribution.xml" --resources "$stage/resources" \
    --package-path "$stage" "$package"
fi
cp "$root/installer/macos/START-HERE.txt" "$out/START-HERE.txt"
(cd "$out" && /usr/bin/shasum -a 256 "$(basename "$package")" > SHA256SUMS.txt)
echo "Installer ready: $package"
echo 'Before public distribution, sign the app, sign the installer, and notarize and staple the installer.'
