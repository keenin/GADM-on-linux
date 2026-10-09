#!/usr/bin/env bash
# Install the GADM launcher into ~/.local/bin and add an application-menu entry.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
DESKTOP_NAME="gadm.desktop"

if [[ ! -f "${SCRIPT_DIR}/gadm" ]]; then
  echo "Cannot find ${SCRIPT_DIR}/gadm. Run install.sh from the GADM-on-linux repository." >&2
  exit 1
fi
if [[ ! -f "${SCRIPT_DIR}/gadm.desktop" ]]; then
  echo "Cannot find ${SCRIPT_DIR}/gadm.desktop." >&2
  exit 1
fi

mkdir -p "${BIN_DIR}" "${APP_DIR}"
install -m 755 "${SCRIPT_DIR}/gadm" "${BIN_DIR}/gadm"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
content=$(<"${SCRIPT_DIR}/gadm.desktop")
printf '%s\n' "${content//@HOME@/${HOME}}" >"${tmp}"
install -m 644 "${tmp}" "${APP_DIR}/${DESKTOP_NAME}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APP_DIR}" || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "Installed:"
echo "  ${BIN_DIR}/gadm"
echo "  ${APP_DIR}/${DESKTOP_NAME}"

missing=()
command -v wine >/dev/null 2>&1 || missing+=("wine (packages: wine, wine32, wine64)")
command -v udisksctl >/dev/null 2>&1 || missing+=("udisksctl (package: udisks2)")
command -v kdialog >/dev/null 2>&1 || missing+=("kdialog (package: kdialog)")

if ((${#missing[@]} > 0)); then
  echo
  echo "The launcher files are installed, but some programs they need are still missing:"
  for item in "${missing[@]}"; do
    echo "  - ${item}"
  done
  echo
  echo "On Debian or Ubuntu:"
  echo "  sudo dpkg --add-architecture i386"
  echo "  sudo apt update"
  echo "  sudo apt install wine wine32 wine64 winetricks cabextract udisks2 kdialog"
  echo
  echo "See README.md for the Wine prefix and the Garmin installer. The menu entry will fail until those programs are installed."
  exit 0
fi

echo
echo "Dependencies look present (wine, udisksctl, kdialog)."
echo "Open \"Garmin Aviation Database Manager\" from the application menu."
