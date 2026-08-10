#!/usr/bin/env bash
# Run once on macOS after copying this folder from Windows / unzip.
# Fixes executable bits and clears quarantine attributes so the App can launch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "→ Fixing permissions under: ${ROOT}"

chmod +x "${ROOT}/build-dmg.sh" 2>/dev/null || true
chmod +x "${ROOT}/prepare-on-mac.sh" 2>/dev/null || true
chmod +x "${ROOT}/scripts/install-openclaw.sh" 2>/dev/null || true
chmod +x "${ROOT}/一键安装-OpenClaw.command" 2>/dev/null || true

if [[ -d "${ROOT}/OpenClaw Installer.app" ]]; then
  chmod +x "${ROOT}/OpenClaw Installer.app/Contents/MacOS/OpenClaw Installer"
  chmod +x "${ROOT}/OpenClaw Installer.app/Contents/Resources/install-openclaw.sh"
  xattr -cr "${ROOT}/OpenClaw Installer.app" 2>/dev/null || true
fi

xattr -cr "${ROOT}/一键安装-OpenClaw.command" 2>/dev/null || true
xattr -cr "${ROOT}/scripts" 2>/dev/null || true

echo "Done."
echo ""
echo "Next:"
echo "  1) Double-click 「OpenClaw Installer」 to install"
echo "  2) Or build a DMG:  ./build-dmg.sh"
echo ""
echo "If macOS still blocks the app: right-click → Open → Open anyway"
