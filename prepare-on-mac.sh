#!/usr/bin/env bash
# Run once on macOS after copying this folder from Windows / unzip.
# Syncs the canonical installer script into the App, fixes executable bits,
# and clears quarantine attributes so the App can launch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${ROOT}/OpenClaw Installer.app"
SRC="${ROOT}/scripts/install-openclaw.sh"
DST="${APP}/Contents/Resources/install-openclaw.sh"

echo "→ Syncing install script into App bundle..."
if [[ ! -f "${SRC}" ]]; then
  echo "ERROR: missing canonical installer: ${SRC}" >&2
  exit 1
fi
if [[ -d "${APP}" ]]; then
  mkdir -p "${APP}/Contents/Resources"
  cp "${SRC}" "${DST}"
  echo "  ${SRC} → ${DST}"
else
  echo "  (skip App sync — ${APP} not found)"
fi

echo "→ Fixing permissions under: ${ROOT}"

chmod +x "${ROOT}/build-dmg.sh" 2>/dev/null || true
chmod +x "${ROOT}/prepare-on-mac.sh" 2>/dev/null || true
chmod +x "${ROOT}/scripts/install-openclaw.sh" 2>/dev/null || true
chmod +x "${ROOT}/一键安装-OpenClaw.command" 2>/dev/null || true

if [[ -d "${APP}" ]]; then
  chmod +x "${APP}/Contents/MacOS/OpenClaw Installer"
  chmod +x "${DST}"
  xattr -cr "${APP}" 2>/dev/null || true
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
