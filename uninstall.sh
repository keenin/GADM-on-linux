#!/usr/bin/env bash
# Remove the GADM launcher and its application-menu entry.
# Restore Wine's powershell.exe from powershell-wine.exe when that backup exists.
# The Wine prefix (default ~/garmin-gadm) and ~/.cache/gadm-launch.log are left in place.
set -euo pipefail

BIN_PATH="${HOME}/.local/bin/gadm"
DESKTOP_PATH="${HOME}/.local/share/applications/gadm.desktop"
APP_DIR="${HOME}/.local/share/applications"

restore_powershell_shim() {
  local dir="$1"
  local backup="${dir}/powershell-wine.exe"
  local current="${dir}/powershell.exe"
  if [[ -e "${backup}" || -L "${backup}" ]]; then
    cp -a "${backup}" "${current}"
    echo "Restored ${current} from powershell-wine.exe"
  fi
}

rm -f "${BIN_PATH}" "${DESKTOP_PATH}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APP_DIR}" || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

prefix="${WINEPREFIX:-${HOME}/garmin-gadm}"
restore_powershell_shim "${prefix}/drive_c/windows/system32/WindowsPowerShell/v1.0"
restore_powershell_shim "${prefix}/drive_c/windows/syswow64/WindowsPowerShell/v1.0"
echo "Removed the launcher and menu entry (if they were installed):"
echo "  ${BIN_PATH}"
echo "  ${DESKTOP_PATH}"
echo "Left in place:"
echo "  ${prefix}"
echo "    Delete that directory yourself if you also want to remove the Windows install."
echo "  ${HOME}/.cache/gadm-launch.log"
