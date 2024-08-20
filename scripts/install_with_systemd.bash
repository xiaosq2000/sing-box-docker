#!/bin/bash
# Be safe.
set -euo pipefail

PROTOCOL="trojan"
XDG_PREFIX_DIR="/usr/local"
SERVICE_DIR="/etc/systemd/system"
SERVICE_NAME="sing-box.service"
SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}"

# Logging
INDENT="  "
print_debug=true
print_verbose=true
RESET=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 6)

error() {
	printf "${RED}${BOLD}ERROR:${RESET} %s\n\r" "$@" >&2
	return 1
}
warning() {
	printf "${YELLOW}${BOLD}WARNING:${RESET} %s\n\r" "$@" >&2
	return 1
}
info() {
	printf "${GREEN}${BOLD}INFO:${RESET} %s\n\r" "$@"
	return 0
}
debug() {
	if [[ $print_debug == "true" ]]; then
		printf "${BOLD}DEBUG:${RESET} %s\n\r" "$@"
	fi
	return 0
}

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
	debug "Replace it with"
	sudo cp "${SERVICE_NAME}" "${SERVICE_FILE}"
else
	sudo cp "${SERVICE_NAME}" "${SERVICE_FILE}"
fi

sudo mkdir -p "${XDG_PREFIX_DIR}/bin"
sudo mkdir -p "${XDG_PREFIX_DIR}/etc/sing-box"
sudo mkdir -p "/var/lib/sing-box/"

if [[ -f "sing-box" ]]; then
	sudo cp ./sing-box "${XDG_PREFIX_DIR}/bin/sing-box"
else
	error "Executable binary file not found."
	exit 1
fi

if [[ -f "${PROTOCOL}-client.json" ]]; then
	sudo cp "${PROTOCOL}-client.json" "${XDG_PREFIX_DIR}/etc/sing-box/config.json"
	debug "Copy ${PROTOCOL}-client.json to ${XDG_PREFIX_DIR}/etc/sing-box/config.json"
elif [[ -f "${PROTOCOL}-server.json" ]]; then
	sudo cp "${PROTOCOL}-server.json" "${XDG_PREFIX_DIR}/etc/sing-box/config.json"
	debug "Copy ${PROTOCOL}-server.json to ${XDG_PREFIX_DIR}/etc/sing-box/config.json"
fi

debug "Systemd Daemon reload."
sudo systemctl daemon-reload >/dev/null 2>&1
debug "Systemd Enable now."
sudo systemctl enable --now ${SERVICE_NAME} >/dev/null 2>&1

info "The networking proxy service, sing-box (${PROTOCOL}), will be managed by systemd from now on.";
info;
info "${INDENT}\$ sudo systemctl status ${SERVICE_NAME}";
info;
info "Try: ";
info;
info "${INDENT}\$ source ${script_dir}/setup.bash";
