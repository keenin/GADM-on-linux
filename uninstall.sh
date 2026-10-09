#!/usr/bin/env bash
# Remove the GADM launcher and its application-menu entry.
# The Wine prefix (default ~/garmin-gadm) and ~/.cache/gadm-launch.log are left in place.
set -euo pipefail

BIN_PATH="${HOME}/.local/bin/gadm"
DESKTOP_PATH="${HOME}/.local/share/applications/gadm.desktop"
APP_DIR="${HOME}/.local/share/applications"

rm -f "${BIN_PATH}" "${DESKTOP_PATH}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${APP_DIR}" || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

prefix="${WINEPREFIX:-${HOME}/garmin-gadm}"
echo "Removed the launcher and menu entry (if they were installed):"
echo "  ${BIN_PATH}"
echo "  ${DESKTOP_PATH}"
echo "Left in place:"
echo "  ${prefix}"
echo "    Delete that directory yourself if you also want to remove the Windows install."
echo "  ${HOME}/.cache/gadm-launch.log"
