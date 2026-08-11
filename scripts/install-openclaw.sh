#!/usr/bin/env bash
# OpenClaw (小龙虾) macOS one-click installer
# Prefer user-local install-cli.sh (no Homebrew/sudo). Fall back to official
# install.sh with a real TTY (NOT curl|bash) so sudo password prompts work.
#
# Canonical copy: scripts/install-openclaw.sh
# prepare-on-mac.sh / build-dmg.sh sync this into OpenClaw Installer.app.
set -euo pipefail

APP_NAME="OpenClaw (小龙虾)"
INSTALL_URL="https://openclaw.ai/install.sh"
INSTALL_CLI_URL="https://openclaw.ai/install-cli.sh"
LOG_DIR="${HOME}/Library/Logs/OpenClawInstaller"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
SKIP_ONBOARD=0
DRY_RUN=0
VERIFY=1
FORCE_SYSTEM=0

usage() {
  cat <<'EOF'
Usage: install-openclaw.sh [options]

  --skip-onboard   Install CLI only; do not run onboarding wizard
  --system         Force official install.sh (may need Homebrew + admin sudo)
  --dry-run        Print actions without installing
  --no-verify      Skip post-install verification
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-onboard) SKIP_ONBOARD=1; shift ;;
    --system) FORCE_SYSTEM=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-verify) VERIFY=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "${LOG_DIR}"

# Log to file AND terminal without stealing stdin.
# Nested official installers are run under a PTY (script) so isatty still works.
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

is_admin_user() {
  id -Gn 2>/dev/null | grep -qw admin
}

check_network() {
  echo "→ Checking network..."
  if ! curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 10 \
      -o /dev/null "${INSTALL_CLI_URL}"; then
    die "Cannot reach ${INSTALL_CLI_URL}. Check network / proxy / firewall."
  fi
  echo "  OK"
}

refresh_path() {
  local npm_bin=""
  if command -v npm >/dev/null 2>&1; then
    npm_bin="$(npm prefix -g 2>/dev/null || true)/bin"
  fi
  export PATH="${HOME}/.openclaw/bin:/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:${HOME}/.npm-global/bin:${npm_bin}:${PATH}"
}

ensure_path_hint() {
  local line='export PATH="$HOME/.openclaw/bin:$PATH"'
  local rc=""
  case "${SHELL##*/}" in
    zsh) rc="${HOME}/.zprofile" ;;
    bash) rc="${HOME}/.bash_profile" ;;
    *) rc="${HOME}/.zprofile" ;;
  esac
  if [[ -f "${HOME}/.openclaw/bin/openclaw" ]] && [[ -n "${rc}" ]]; then
    touch "${rc}"
    if ! grep -qF '.openclaw/bin' "${rc}" 2>/dev/null; then
      echo "" >> "${rc}"
      echo "# OpenClaw" >> "${rc}"
      echo "${line}" >> "${rc}"
      echo "→ Added PATH to ${rc}"
    fi
  fi
}

resolve_openclaw() {
  refresh_path
  if command -v openclaw >/dev/null 2>&1; then
    command -v openclaw
    return 0
  fi
  return 1
}

gateway_ready() {
  local bin="$1"
  # Non-zero or empty output → treat as not ready (daemon may be missing).
  "${bin}" gateway status >/dev/null 2>&1
}

# Download to a file then run — keeps stdin as the Terminal TTY (unlike curl|bash).
run_script_file() {
  local url="$1"
  shift
  local tmp
  tmp="$(mktemp -t openclaw-install.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}' '${tmp}.typescript'" RETURN
  echo "→ Downloading: ${url}"
  curl -fsSL --proto '=https' --tlsv1.2 "${url}" -o "${tmp}"
  chmod +x "${tmp}"
  echo "→ Running installer with interactive Terminal (sudo prompts work here)..."
  echo ""
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] bash ${tmp} $*"
    return 0
  fi

  local rc=0
  # Prefer a PTY so nested tools see a real TTY on stdout (not only stdin).
  # Parent may have stdout wired through tee for logging (display is already logged).
  if [[ -c /dev/tty ]] && command -v script >/dev/null 2>&1; then
    script -q "${tmp}.typescript" bash "${tmp}" "$@" </dev/tty || rc=$?
    rm -f "${tmp}.typescript"
  else
    bash "${tmp}" "$@" </dev/tty || rc=$?
  fi
  return "${rc}"
}

run_local_prefix_installer() {
  echo "→ Using user-local installer (no Homebrew / no admin sudo required)"
  echo "  Source: ${INSTALL_CLI_URL}"
  echo "  Prefix: ~/.openclaw"
  echo "  Onboard: handled by this wrapper (openclaw onboard --install-daemon)"
  echo ""

  # Always skip official onboard here so we only run one unified onboard path
  # that includes --install-daemon (avoids config-without-daemon gaps).
  run_script_file "${INSTALL_CLI_URL}" --no-onboard
  ensure_path_hint
}

run_system_installer() {
  echo "→ Using official system installer"
  echo "  Source: ${INSTALL_URL}"
  echo "  Note: missing Node may install Homebrew (needs Administrator password)."
  echo "  Onboard: handled by this wrapper (openclaw onboard --install-daemon)"
  echo ""

  if ! is_admin_user; then
    echo "⚠ Current user is not in the 'admin' group."
    echo "  Homebrew install will fail. Prefer the default user-local path,"
    echo "  or switch to an Administrator account."
    echo ""
  fi

  # Do NOT pass --no-prompt: Homebrew/sudo must be able to ask for a password.
  # Onboard is unified below — do not double-run official --onboard.
  local flags=(--no-onboard)
  if [[ "${VERIFY}" -eq 1 ]]; then
    flags+=(--verify)
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    flags+=(--dry-run)
  fi

  run_script_file "${INSTALL_URL}" "${flags[@]}"
}

run_installer() {
  if [[ "${FORCE_SYSTEM}" -eq 1 ]]; then
    run_system_installer
    return
  fi

  # Default: avoid Homebrew/sudo failure seen on non-admin or non-TTY installs.
  if run_local_prefix_installer; then
    return 0
  fi

  echo ""
  echo "⚠ User-local install failed; trying official install.sh ..."
  echo ""
  run_system_installer
}

run_onboard_if_needed() {
  if [[ "${SKIP_ONBOARD}" -eq 1 || "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  local bin
  if ! bin="$(resolve_openclaw)"; then
    echo "⚠ openclaw not found on PATH after install."
    echo "  Open a new Terminal and run: openclaw onboard --install-daemon"
    echo "  Or: export PATH=\"\$HOME/.openclaw/bin:\$PATH\""
    return 0
  fi

  local has_config=0
  if [[ -f "${HOME}/.openclaw/openclaw.json" ]]; then
    has_config=1
  fi

  if [[ "${has_config}" -eq 1 ]] && gateway_ready "${bin}"; then
    echo "→ Config and gateway look ready — skipping onboard."
    return 0
  fi

  if [[ "${has_config}" -eq 1 ]]; then
    echo "→ Config found at ~/.openclaw/openclaw.json, but gateway is not ready."
    echo "  Running: ${bin} onboard --install-daemon"
  else
    echo "→ Starting onboarding wizard (API key / gateway / daemon)..."
    echo "  Command: ${bin} onboard --install-daemon"
  fi
  echo ""

  if [[ -c /dev/tty ]] && command -v script >/dev/null 2>&1; then
    local cap
    cap="$(mktemp -t openclaw-onboard.XXXXXX)"
    script -q "${cap}" "${bin}" onboard --install-daemon </dev/tty || {
      echo "⚠ Onboarding did not finish. You can rerun later:"
      echo "  openclaw onboard --install-daemon"
    }
    rm -f "${cap}"
  else
    "${bin}" onboard --install-daemon </dev/tty || {
      echo "⚠ Onboarding did not finish. You can rerun later:"
      echo "  openclaw onboard --install-daemon"
    }
  fi
}

verify_install() {
  echo ""
  echo "→ Verifying installation..."
  refresh_path

  if ! resolve_openclaw >/dev/null; then
    echo "⚠ 'openclaw' not found on PATH."
    echo "  Try: export PATH=\"\$HOME/.openclaw/bin:\$PATH\""
    echo "  Then open a new Terminal window."
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

If 'openclaw' is not found:
  export PATH="\$HOME/.openclaw/bin:\$PATH"
  # or open a NEW Terminal window

Docs: https://docs.openclaw.ai/start/getting-started
Log: ${LOG_FILE}
EOF
}

print_preflight() {
  echo "User: $(whoami)"
  if is_admin_user; then
    echo "Admin: yes"
  else
    echo "Admin: no (user-local install does not need admin)"
  fi
  if [[ -t 0 ]] || [[ -c /dev/tty ]]; then
    echo "TTY: available"
  else
    echo "TTY: missing — open via Terminal / OpenClaw Installer.app"
  fi
  echo ""
}

main() {
  banner
  require_macos
  print_preflight
  check_network
  run_installer
  run_onboard_if_needed
  if [[ "${VERIFY}" -eq 1 && "${DRY_RUN}" -eq 0 ]]; then
    verify_install || true
  fi
  print_next_steps
}

main "$@"
