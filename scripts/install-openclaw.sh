#!/usr/bin/env bash
# OpenClaw (小龙虾) macOS one-click installer
# Wraps the official installer: https://openclaw.ai/install.sh
set -euo pipefail

APP_NAME="OpenClaw (小龙虾)"
INSTALL_URL="https://openclaw.ai/install.sh"
LOG_DIR="${HOME}/Library/Logs/OpenClawInstaller"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
SKIP_ONBOARD=0
DRY_RUN=0
VERIFY=1

usage() {
  cat <<'EOF'
Usage: install-openclaw.sh [options]

  --skip-onboard   Install CLI only; do not run onboarding wizard
  --dry-run        Print actions without installing
  --no-verify      Skip post-install verification
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-onboard) SKIP_ONBOARD=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-verify) VERIFY=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

banner() {
  echo ""
  echo "=============================================="
  echo "  ${APP_NAME} macOS Installer"
  echo "=============================================="
  echo ""
}

die() {
  echo ""
  echo "ERROR: $*" >&2
  echo "Log: ${LOG_FILE}" >&2
  exit 1
}

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This installer only supports macOS."
}

check_network() {
  echo "→ Checking network..."
  if ! curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 10 \
      -o /dev/null -w '' "${INSTALL_URL}"; then
    die "Cannot reach ${INSTALL_URL}. Check network / proxy / firewall."
  fi
  echo "  OK"
}

refresh_path() {
  # Common locations after official install / Homebrew / npm
  export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${HOME}/.npm-global/bin:$(npm prefix -g 2>/dev/null)/bin:${PATH}"
}

resolve_openclaw() {
  refresh_path
  if command -v openclaw >/dev/null 2>&1; then
    command -v openclaw
    return 0
  fi
  return 1
}

run_official_installer() {
  echo "→ Downloading and running official OpenClaw installer..."
  echo "  Source: ${INSTALL_URL}"
  echo ""

  local flags=(--no-prompt)
  if [[ "${SKIP_ONBOARD}" -eq 1 ]]; then
    flags+=(--no-onboard)
  else
    flags+=(--onboard)
  fi
  if [[ "${VERIFY}" -eq 1 ]]; then
    flags+=(--verify)
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    flags+=(--dry-run)
  fi

  # shellcheck disable=SC2068
  curl -fsSL --proto '=https' --tlsv1.2 "${INSTALL_URL}" | bash -s -- ${flags[@]}
}

run_onboard_if_needed() {
  if [[ "${SKIP_ONBOARD}" -eq 1 || "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  local bin
  if ! bin="$(resolve_openclaw)"; then
    echo "⚠ openclaw not found on PATH after install."
    echo "  Open a new Terminal and run: openclaw onboard --install-daemon"
    return 0
  fi

  # Official installer may already have run onboard when TTY is available.
  # If config exists, skip; otherwise launch wizard.
  if [[ -f "${HOME}/.openclaw/openclaw.json" ]]; then
    echo "→ Config found at ~/.openclaw/openclaw.json — skipping extra onboard."
    return 0
  fi

  echo "→ Starting onboarding wizard (API key / gateway / daemon)..."
  echo "  Command: ${bin} onboard --install-daemon"
  echo ""
  "${bin}" onboard --install-daemon || {
    echo "⚠ Onboarding did not finish. You can rerun later:"
    echo "  openclaw onboard --install-daemon"
  }
}

verify_install() {
  echo ""
  echo "→ Verifying installation..."
  refresh_path

  if ! resolve_openclaw >/dev/null; then
    echo "⚠ 'openclaw' not found on PATH."
    echo "  Try: hash -r  (or open a new Terminal window)"
    echo "  Also check: npm prefix -g"
    return 1
  fi

  echo "  openclaw: $(command -v openclaw)"
  openclaw --version || true

  if command -v openclaw >/dev/null 2>&1; then
    openclaw doctor --non-interactive 2>/dev/null || openclaw doctor || true
    openclaw gateway status 2>/dev/null || true
  fi
  echo "  Log saved to: ${LOG_FILE}"
}

print_next_steps() {
  cat <<EOF

==============================================
  Installation finished
==============================================

Next steps:
  1. openclaw dashboard          # open Control UI
  2. openclaw gateway status     # check Gateway
  3. openclaw configure          # adjust models / channels

If 'openclaw' is not found, open a NEW Terminal and try again.
Docs: https://docs.openclaw.ai/start/getting-started

Log: ${LOG_FILE}
EOF
}

main() {
  banner
  require_macos
  check_network
  run_official_installer
  run_onboard_if_needed
  if [[ "${VERIFY}" -eq 1 && "${DRY_RUN}" -eq 0 ]]; then
    verify_install || true
  fi
  print_next_steps
}

main "$@"
