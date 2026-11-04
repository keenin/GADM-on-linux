#!/usr/bin/env bash
# Cross-compile powershell-shim.c to 64-bit and 32-bit Windows executables.
# Uses mingw-w64 when those compilers are installed, otherwise zig cc
# (zig on PATH, or `python3 -m ziglang cc` after `pip install ziglang`).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${ROOT}"

if [[ ! -f powershell-shim.c ]]; then
  echo "powershell-shim.c is not in ${ROOT}" >&2
  exit 1
fi

run_zig_cc() {
  if command -v zig >/dev/null 2>&1; then
    zig cc "$@"
  elif command -v python3 >/dev/null 2>&1 && python3 -c 'import ziglang' >/dev/null 2>&1; then
    python3 -m ziglang cc "$@"
  else
    echo "No Windows C compiler found." >&2
    echo "Install mingw-w64 (x86_64-w64-mingw32-gcc and i686-w64-mingw32-gcc)," >&2
    echo "or install zig: python3 -m venv .venv && .venv/bin/pip install ziglang" >&2
    exit 1
  fi
}

compile_one() {
  local output="$1"
  local mingw="$2"
  local zig_target="$3"
  if command -v "${mingw}" >/dev/null 2>&1; then
    "${mingw}" -municode -O2 -s -o "${output}" powershell-shim.c -lshell32
  else
    run_zig_cc -target "${zig_target}" -municode -O2 -s -o "${output}" powershell-shim.c -lshell32
  fi
  chmod 755 "${output}"
  echo "built ${ROOT}/${output}"
}

compile_one powershell64.exe x86_64-w64-mingw32-gcc x86_64-windows-gnu
compile_one powershell32.exe i686-w64-mingw32-gcc x86-windows-gnu
