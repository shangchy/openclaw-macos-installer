#!/usr/bin/env bash
# Build a distributable DMG on macOS.
# Usage (on a Mac):
#   chmod +x build-dmg.sh
#   ./build-dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OpenClaw Installer"
APP_PATH="${ROOT}/${APP_NAME}.app"
STAGE="${ROOT}/dist/dmg-stage"
VERSION="${OPENCLAW_INSTALLER_VERSION:-1.0.0}"
DMG_NAME="OpenClaw-Installer-macOS-${VERSION}.dmg"
DMG_PATH="${ROOT}/dist/${DMG_NAME}"
VOL_NAME="OpenClaw 小龙虾安装器"
SRC_SCRIPT="${ROOT}/scripts/install-openclaw.sh"
APP_SCRIPT="${APP_PATH}/Contents/Resources/install-openclaw.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "build-dmg.sh must be run on macOS."
[[ -d "${APP_PATH}" ]] || die "Missing app bundle: ${APP_PATH}"
[[ -f "${SRC_SCRIPT}" ]] || die "Missing canonical installer: ${SRC_SCRIPT}"

echo "→ Syncing canonical install script into App..."
mkdir -p "${APP_PATH}/Contents/Resources"
cp "${SRC_SCRIPT}" "${APP_SCRIPT}"

echo "→ Fixing executable bits..."
chmod +x "${APP_PATH}/Contents/MacOS/OpenClaw Installer"
chmod +x "${APP_SCRIPT}"
chmod +x "${SRC_SCRIPT}"
chmod +x "${ROOT}/一键安装-OpenClaw.command" 2>/dev/null || true

# Clear quarantine on the build machine so the staged copy is clean;
# end users may still need right-click → Open the first time (unsigned).
xattr -cr "${APP_PATH}" 2>/dev/null || true

echo "→ Staging DMG contents..."
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
ditto "${APP_PATH}" "${STAGE}/${APP_NAME}.app"
cp "${ROOT}/一键安装-OpenClaw.command" "${STAGE}/" 2>/dev/null || true
cp "${ROOT}/使用说明.txt" "${STAGE}/" 2>/dev/null || true
cp "${ROOT}/OpenClaw用户手册.txt" "${STAGE}/" 2>/dev/null || true
cp "${ROOT}/飞书接入说明.txt" "${STAGE}/" 2>/dev/null || true
# No Applications link: this is a run-once installer, not an app to copy into /Applications.

echo "→ Creating ${DMG_PATH}..."
mkdir -p "${ROOT}/dist"
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

rm -rf "${STAGE}"

# Also zip the .app for AirDrop / WeChat transfer
ZIP_PATH="${ROOT}/dist/OpenClaw-Installer-macOS-${VERSION}.zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo ""
echo "Done."
echo "  DMG: ${DMG_PATH}"
echo "  ZIP: ${ZIP_PATH}"
echo ""
echo "Optional (Apple Developer ID):"
echo "  codesign --deep --force --options runtime --sign \"Developer ID Application: YOUR NAME\" \"${APP_PATH}\""
echo "  then re-run this script, and notarize the DMG with notarytool."
