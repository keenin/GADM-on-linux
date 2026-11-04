#!/usr/bin/env bash
# Install the GADM launcher into ~/.local/bin, add an application-menu entry,
# and replace Wine's powershell.exe stub so GADM's in-app updater can start.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
DESKTOP_NAME="gadm.desktop"

# system32 gets the 64-bit shim. syswow64 gets the 32-bit shim, which is the
# one 32-bit GADM actually runs. Never overwrite an existing powershell-wine.exe.
install_powershell_shim_dir() {
  local dir="$1"
  local shim="$2"
  local backup="${dir}/powershell-wine.exe"
  local current="${dir}/powershell.exe"

  if [[ ! -f "${shim}" ]]; then
    echo "warning: ${shim} is missing. Run powershell-shim/build.sh, then install.sh again." >&2
    return 0
  fi
  if [[ ! -d "${dir}" ]]; then
    echo "warning: ${dir} does not exist. Create the Wine prefix, then re-run install.sh to enable in-app updates." >&2
    return 0
  fi
  if [[ ! -e "${backup}" && ! -L "${backup}" ]]; then
    if [[ ! -e "${current}" && ! -L "${current}" ]]; then
      echo "warning: ${current} is missing, so Wine's PowerShell cannot be saved. Skipping the shim in this folder." >&2
      return 0
    fi
    if cmp -s "${current}" "${shim}"; then
      echo "warning: ${backup} is missing and ${current} is already the shim. Restore Wine's powershell.exe, then re-run install.sh." >&2
      return 0
    fi
    cp -a "${current}" "${backup}"
    echo "Saved Wine's PowerShell as ${backup}"
  fi
  install -m 755 "${shim}" "${current}"
  echo "  ${current}"
}

install_powershell_shim() {
  local prefix="${WINEPREFIX:-${HOME}/garmin-gadm}"
  install_powershell_shim_dir \
    "${prefix}/drive_c/windows/system32/WindowsPowerShell/v1.0" \
    "${SCRIPT_DIR}/powershell-shim/powershell64.exe"
  install_powershell_shim_dir \
    "${prefix}/drive_c/windows/syswow64/WindowsPowerShell/v1.0" \
    "${SCRIPT_DIR}/powershell-shim/powershell32.exe"
}

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
install_powershell_shim

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
