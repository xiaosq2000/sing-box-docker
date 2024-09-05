#!/usr/bin/env bash
# Be safe.
set -euo pipefail

PROTOCOL="trojan"

# Logging
print_debug=true
print_verbose=true

INDENT='    '
BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
error() {
	printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >&2
}
warning() {
	printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
debug() {
	printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
}

usage() {
    printf "%s\n" \
        "Usage: " \
        "${INDENT}$0 [option]" \
        ""
    printf "%s\n" \
        "Options: " \
        "${INDENT}-h, --help                  Display help messeges" \
        "${INDENT}-p, --protocol PROTOCOL     Specify which protocol to install" \
        ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    -p | --protocol)
        PROTOCOL="$2"
        shift 2
        ;;
    *)
        error "Unknown argument: $1"
        usage
        ;;
    esac
done

if [[ $PROTOCOL != "trojan" && $PROTOCOL != "hysteria2" ]]; then
    error "$PROTOCOL is not supported yet."
    exit 1
fi

XDG_PREFIX_DIR="/usr/local"
SERVICE_DIR="/etc/systemd/system"
SERVICE_NAME="sing-box-${PROTOCOL}.service"
SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}"

# Superuser privilege is required.
if [[ $(id -u) -ne 0 ]]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd ${script_dir}

if [[ -f "${SERVICE_FILE}" ]]; then
	debug "Detected pre-existed ${SERVICE_NAME} in $SERVICE_DIR."
	debug "Stop and disable it."
	sudo systemctl stop ${SERVICE_NAME} >/dev/null 2>&1
	sudo systemctl disable ${SERVICE_NAME} >/dev/null 2>&1
	debug "Replace it with ${SERVICE_NAME} in ${script_dir}."
	sudo cp "${SERVICE_NAME}" "${SERVICE_FILE}"
else
	sudo cp "${SERVICE_NAME}" "${SERVICE_FILE}"
fi

sudo mkdir -p "${XDG_PREFIX_DIR}/bin"
sudo mkdir -p "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}"
sudo mkdir -p "/var/lib/sing-box/"

if [[ -f "sing-box" ]]; then
	sudo cp ./sing-box "${XDG_PREFIX_DIR}/bin/sing-box"
else
	error "Executable binary file, sing-box, is not found."
	exit 1
fi

if [[ -f "${PROTOCOL}-client.json" ]]; then
	sudo cp "${PROTOCOL}-client.json" "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
	debug "Copy ${PROTOCOL}-client.json to ${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
elif [[ -f "${PROTOCOL}-server.json" ]]; then
	sudo cp "${PROTOCOL}-server.json" "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
	debug "Copy ${PROTOCOL}-server.json to ${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
fi

debug "Systemd Daemon reload."
sudo systemctl daemon-reload >/dev/null 2>&1
debug "Systemd Enable now."
sudo systemctl enable --now ${SERVICE_NAME} >/dev/null 2>&1

info "The networking proxy service, sing-box (${PROTOCOL}), will be managed by systemd from now on.

    Try: 

    ${INDENT}${GREEN}${BOLD}\$${RESET} sudo systemctl status ${SERVICE_NAME}

    To use some handy commands:

    ${INDENT}${GREEN}${BOLD}\$${RESET} source ${script_dir}/setup.bash
    "
