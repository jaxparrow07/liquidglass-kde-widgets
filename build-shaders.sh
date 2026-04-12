#!/usr/bin/env bash

# Precompile GLSL shaders to Qt's .qsb format.
# Run this whenever 1-common/components/shaders/*.frag changes.
# Requires qsb from qt6-base-dev-tools.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHADER_DIR="${SCRIPT_DIR}/1-common/components/shaders"

QSB="$(command -v qsb || echo /usr/lib/qt6/bin/qsb)"
if [[ ! -x "$QSB" ]]; then
	echo "[!] qsb not found. Install qt6-base-dev-tools."
	exit 1
fi

shopt -s nullglob
FRAGS=("${SHADER_DIR}"/*.frag)
if [[ ${#FRAGS[@]} -eq 0 ]]; then
	echo "[!] No .frag shaders found in ${SHADER_DIR}"
	exit 1
fi

for frag in "${FRAGS[@]}"; do
	out="${frag}.qsb"
	echo "[*] Compiling $(basename "$frag") -> $(basename "$out")"
	"$QSB" --glsl "300 es,330" --hlsl 50 --msl 12 -o "$out" "$frag"
done

echo "[+] Shaders compiled."
