#!/usr/bin/env bash
# Be safe.
set -euo pipefail

PROTOCOL="trojan"
XDG_PREFIX_DIR="/usr/local"
SERVICE_FILE_DIR="/etc/systemd/system"
SERVICE_FILE_NAME="sing-box.service"
SERVICE_FILE_PATH="${SERVICE_FILE_DIR}/${SERVICE_FILE_NAME}"

# Logging
RESET=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 6)

error() {
    printf "${RED}${BOLD}ERROR:${RESET} %s\n" "$@" >&2
    return 1;
}
warning() {
    printf "${YELLOW}${BOLD}WARNING:${RESET} %s\n" "$@" >&2
    return 1;
}
info() {
    printf "${GREEN}${BOLD}INFO:${RESET} %s\n" "$@"
    return 0;
}
debug() {
    if [[ $print_debug == "true" ]]; then
        printf "${BOLD}DEBUG:${RESET} %s\n" "$@"
    else
        ;
    fi
}

# Superuser privilege is required.
if ! [ $(id -u) = 0 ]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi

# The parent folder of this script.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $script_dir

if [[ -f "${SERVICE_FILE}" ]]; then
    sudo systemctl stop ${SERVICE_FILE_NAME}
    sudo systemctl disable ${SERVICE_FILE_NAME}
    sudo cp ./${SERVICE_FILE_NAME} ${SERVICE_FILE_PATH}
else
    sudo cp ./${SERVICE_FILE_NAME} ${SERVICE_FILE_PATH}
fi

sudo mkdir -p "${XDG_PREFIX_DIR}/bin"
sudo mkdir -p "${XDG_PREFIX_DIR}/etc/sing-box"
sudo mkdir -p /var/lib/sing-box/

sudo cp sing-box "${XDG_PREFIX_DIR}/bin/sing-box"

if [[ -f "${PROTOCOL}-client.json" ]]; then
    sudo cp ${PROTOCOL}-client.json ${XDG_PREFIX_DIR}/etc/sing-box/config.json
elif [[ -f "${PROTOCOL}-server.json" ]]; then
    sudo cp ${PROTOCOL}-server.json ${XDG_PREFIX_DIR}/etc/sing-box/config.json
fi

info "Networking proxy service, sing-box (${PROTOCOL}), will be managed by systemd."

sudo systemctl enable --now sing-box.service
