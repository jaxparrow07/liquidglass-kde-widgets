#!/usr/bin/env bash

# Package KDE Plasma widgets into distributable .plasmoid files

set -e

PACKAGE_DIR="2-packaged"
PACKAGES_SRC="packages"

package_widget() {
	local WIDGET_NAME="$1"
	local WIDGET_DIR="${PACKAGES_SRC}/${WIDGET_NAME}"
	local METADATA_FILE="${WIDGET_DIR}/metadata.json"

	if [[ ! -f "$METADATA_FILE" ]]; then
		echo "[!] Error: metadata.json not found in ${WIDGET_NAME}"
		return 1
	fi

	echo ""
	echo "================================"
	echo "[*] Packaging: ${WIDGET_NAME}"
	echo "================================"

	local WIDGET_ID=$(jq -r '.KPlugin.Id' "$METADATA_FILE")
	local VERSION=$(jq -r '.KPlugin.Version' "$METADATA_FILE")

	if [[ -z "$WIDGET_ID" || "$WIDGET_ID" == "null" ]]; then
		echo "[!] Error: Invalid widget ID in metadata.json"
		return 1
	fi

	local OUTPUT_NAME="${WIDGET_NAME}"
	if [[ -n "$VERSION" && "$VERSION" != "null" ]]; then
		OUTPUT_NAME="${WIDGET_NAME}-${VERSION}"
	fi
	local OUTPUT_FILE="${PACKAGE_DIR}/${OUTPUT_NAME}.plasmoid"

	local TEMP_DIR=$(mktemp -d)
	trap "rm -rf $TEMP_DIR" EXIT

	echo "[*] Copying widget files (dereferencing symlinks)..."
	tar -C "${WIDGET_DIR}" -chf - . | tar -C "$TEMP_DIR" -xf -

	echo "[*] Cleaning up development files..."
	find "$TEMP_DIR" -name "*.swp" -delete 2>/dev/null || true
	find "$TEMP_DIR" -name "*.swo" -delete 2>/dev/null || true
	find "$TEMP_DIR" -name "*~" -delete 2>/dev/null || true
	find "$TEMP_DIR" -name ".DS_Store" -delete 2>/dev/null || true

	mkdir -p "$PACKAGE_DIR"
	local ABS_OUTPUT=$(realpath "$OUTPUT_FILE")

	echo "[*] Creating .plasmoid package..."
	pushd "$TEMP_DIR" > /dev/null
	zip -q -r "$ABS_OUTPUT" .
	popd > /dev/null

	echo "[+] Package created successfully!"
	echo "    Widget ID: ${WIDGET_ID}"
	echo "    Version: ${VERSION}"
	echo "    Output: ${ABS_OUTPUT}"
	echo "    Size: $(du -h "$OUTPUT_FILE" | cut -f1)"

	return 0
}

if [[ "$1" == "--all" || "$1" == "-a" ]]; then
	echo "[*] Packaging all widgets..."

	WIDGETS=($(ls -d ${PACKAGES_SRC}/*/ 2>/dev/null | xargs -n 1 basename))

	if [[ ${#WIDGETS[@]} -eq 0 ]]; then
		echo "[!] No widgets found in ${PACKAGES_SRC} directory"
		exit 1
	fi

	for widget in "${WIDGETS[@]}"; do
		package_widget "$widget" || echo "[!] Failed: $widget"
	done

	echo ""
	echo "[+] All packages saved to: $(realpath $PACKAGE_DIR)"

elif [[ -n "$1" && -d "${PACKAGES_SRC}/$1" ]]; then
	package_widget "$1"
	echo "[+] Packaging complete!"
else
	if [[ -n "$1" ]]; then
		echo "[!] Widget package not found: $1"
	fi
	echo "[+] Available widgets:"
	ls "$PACKAGES_SRC"
	echo ""
	echo "Usage:"
	echo "  ./package.sh <package_folder>    Package a single widget"
	echo "  ./package.sh --all | -a          Package all widgets"
	exit 1
fi
