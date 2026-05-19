#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[38;5;83m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;203m'
CYAN='\033[38;5;117m'
BLUE='\033[38;5;75m'
GRAY='\033[38;5;244m'

_info()    { echo -e "${CYAN}  →${RESET} $*"; }
_success() { echo -e "${GREEN}  ✓${RESET} $*"; }
_warn()    { echo -e "${YELLOW}  ⚠${RESET} $*"; }
_error()   { echo -e "${RED}  ✗${RESET} $*"; }
_dim()     { echo -e "${GRAY}$*${RESET}"; }
_header()  { echo -e "\n${BOLD}${BLUE}$*${RESET}"; }
_divider() { echo -e "${GRAY}  ────────────────────────────────${RESET}"; }

spinner() {
	local pid=$1
	local label="${2:-Working}"
	local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
	local i=0
	tput civis 2>/dev/null || true
	while kill -0 "$pid" 2>/dev/null; do
		printf "\r  ${CYAN}%s${RESET}  %s " "${frames[$i]}" "$label"
		i=$(( (i + 1) % ${#frames[@]} ))
		sleep 0.08
	done
	printf "\r\033[K"
	tput cnorm 2>/dev/null || true
}

restart_plasmashell() {
	_header "Reloading Plasmashell"

	if pgrep -x plasmashell >/dev/null; then
		if command -v kquitapp6 >/dev/null; then
			kquitapp6 plasmashell >/dev/null 2>&1 || true
		elif command -v qdbus6 >/dev/null; then
			qdbus6 org.kde.plasmashell /MainApplication quit >/dev/null 2>&1 || true
		else
			_warn "kquitapp6/qdbus6 not found — falling back to SIGTERM"
			killall plasmashell >/dev/null 2>&1 || true
		fi

		for _ in {1..50}; do
			if ! pgrep -x plasmashell >/dev/null; then
				break
			fi
			sleep 0.1
		done

		if pgrep -x plasmashell >/dev/null; then
			_warn "Plasmashell did not quit cleanly — sending SIGTERM"
			killall plasmashell >/dev/null 2>&1 || true
			sleep 0.5
		fi
	fi

	if command -v kstart6 >/dev/null; then
		kstart6 plasmashell >/dev/null 2>&1 &
	elif command -v kstart >/dev/null; then
		kstart plasmashell >/dev/null 2>&1 &
	else
		nohup plasmashell >/dev/null 2>&1 &
	fi

	spinner $! "Starting plasmashell"
	_success "Plasmashell reloaded"
}

install_widget() {
	local WIDGET_NAME="$1"
	local SKIP_RELOAD="${2:-false}"
	local WIDGET_DIR="packages/${WIDGET_NAME}"
	local METADATA_FILE="${WIDGET_DIR}/metadata.json"

	_header "Installing: ${WIDGET_NAME}"
	_divider

	local widgetId
	widgetId=$(jq -r ".KPlugin.Id" "$METADATA_FILE")

	local install_result=0
	if [[ -d "$HOME/.local/share/plasma/plasmoids/${widgetId}" ]]; then
		_info "Updating ${DIM}${widgetId}${RESET}"
		if [[ "$VERBOSE" == "true" ]]; then
			kpackagetool6 --type=Plasma/Applet -u "${WIDGET_DIR}" 2>&1 || install_result=$?
		else
			kpackagetool6 --type=Plasma/Applet -u "${WIDGET_DIR}" >/dev/null 2>&1 || install_result=$?
		fi
	else
		_info "Installing ${DIM}${widgetId}${RESET}"
		if [[ "$VERBOSE" == "true" ]]; then
			kpackagetool6 --type=Plasma/Applet -i "${WIDGET_DIR}" 2>&1 || install_result=$?
		else
			kpackagetool6 --type=Plasma/Applet -i "${WIDGET_DIR}" >/dev/null 2>&1 || install_result=$?
		fi
	fi

	if [[ $install_result -eq 0 ]]; then
		_success "Done"
	else
		_error "Failed"
		return 1
	fi

	if [[ "$SKIP_RELOAD" != "true" ]]; then
		restart_plasmashell
	fi

	return 0
}

print_usage() {
	echo -e "\n${BOLD}Usage${RESET}"
	echo -e "  ${CYAN}./install.sh${RESET} ${GREEN}<name>${RESET}     Install a single widget"
	echo -e "  ${CYAN}./install.sh${RESET} ${GREEN}-a${RESET}         Install all non-test widgets"
	echo -e "  ${CYAN}./install.sh${RESET} ${GREEN}-t${RESET}         Install only test-* widgets"
	echo -e "  ${CYAN}./install.sh${RESET} ${GREEN}-a -t${RESET}      Install everything"
	echo -e "  ${CYAN}./install.sh${RESET} ${GREEN}-v${RESET}         Verbose output (show kpackagetool6 logs)"
}

# Parse flags and positional name
WANT_ALL=false
WANT_TEST=false
VERBOSE=false
WIDGET_NAME=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		-a|--all)     WANT_ALL=true;  shift ;;
		-t|--test)    WANT_TEST=true; shift ;;
		-v|--verbose) VERBOSE=true;   shift ;;
		-at|-ta)      WANT_ALL=true; WANT_TEST=true; shift ;;
		-h|--help)  print_usage; exit 0 ;;
		-*)
			_error "Unknown flag: $1"
			print_usage
			exit 1
			;;
		*)
			if [[ -n "$WIDGET_NAME" ]]; then
				_error "Multiple widget names not supported: $WIDGET_NAME and $1"
				exit 1
			fi
			WIDGET_NAME="$1"
			shift
			;;
	esac
done

if [[ "$WANT_ALL" == "true" || "$WANT_TEST" == "true" ]]; then
	if [[ -n "$WIDGET_NAME" ]]; then
		_error "Cannot combine a widget name with -a / -t"
		exit 1
	fi

	ALL_WIDGETS=($(ls -d packages/*/ 2>/dev/null | xargs -n 1 basename))
	if [[ ${#ALL_WIDGETS[@]} -eq 0 ]]; then
		_error "No widgets found in packages/"
		exit 1
	fi

	WIDGETS=()
	for widget in "${ALL_WIDGETS[@]}"; do
		if [[ "$widget" == test-* ]]; then
			[[ "$WANT_TEST" == "true" ]] && WIDGETS+=("$widget")
		else
			[[ "$WANT_ALL" == "true" ]] && WIDGETS+=("$widget")
		fi
	done

	if [[ ${#WIDGETS[@]} -eq 0 ]]; then
		_error "No matching widgets to install"
		exit 1
	fi

	_header "Widgets to install"
	for widget in "${WIDGETS[@]}"; do
		_dim "    ${widget}"
	done

	FAILED_WIDGETS=()
	SUCCESSFUL_WIDGETS=()

	for widget in "${WIDGETS[@]}"; do
		if install_widget "$widget" "true"; then
			SUCCESSFUL_WIDGETS+=("$widget")
		else
			FAILED_WIDGETS+=("$widget")
		fi
	done

	_header "Summary"
	_divider
	echo -e "  ${GREEN}✓ Installed: ${#SUCCESSFUL_WIDGETS[@]}${RESET}"
	for widget in "${SUCCESSFUL_WIDGETS[@]}"; do
		echo -e "    ${GRAY}${widget}${RESET}"
	done

	if [[ ${#FAILED_WIDGETS[@]} -gt 0 ]]; then
		echo -e "  ${RED}✗ Failed: ${#FAILED_WIDGETS[@]}${RESET}"
		for widget in "${FAILED_WIDGETS[@]}"; do
			echo -e "    ${GRAY}${widget}${RESET}"
		done
	fi

	echo ""
	restart_plasmashell

	echo ""
	_success "All done!"

elif [[ -n "$WIDGET_NAME" && -d "packages/$WIDGET_NAME" ]]; then
	install_widget "$WIDGET_NAME" "false"
	echo ""
	_success "Installation complete!"
else
	if [[ -n "$WIDGET_NAME" ]]; then
		_error "Widget package not found: ${WIDGET_NAME}"
	else
		_error "No widget specified"
	fi

	echo -e "\n  ${GRAY}Widgets:${RESET}"
	for pkg in packages/*/; do
		name=$(basename "$pkg")
		[[ "$name" == test-* ]] || echo -e "    ${CYAN}${name}${RESET}"
	done
	echo -e "\n  ${GRAY}Test packages:${RESET}"
	for pkg in packages/*/; do
		name=$(basename "$pkg")
		[[ "$name" == test-* ]] && echo -e "    ${GRAY}${name}${RESET}"
	done

	print_usage
	exit 1
fi
