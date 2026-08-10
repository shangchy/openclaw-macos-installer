#!/usr/bin/env bash
# Double-click fallback installer (no .app needed).
# On macOS Finder: double-click this file → Terminal opens → install runs.
cd "$(dirname "$0")" || exit 1
bash "./scripts/install-openclaw.sh"
echo ""
echo "按任意键关闭…"
read -n 1 -s || true
