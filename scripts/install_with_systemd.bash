#!/usr/bin/env bash
# Be safe.
set -eo pipefail

# Logging
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
	if [[ $VERBOSE == true ]]; then
		printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
	fi
}
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}

usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		""
	printf "%s\n" \
		"Options: " \
		"${INDENT}-h, --help                  Display help messeges" \
		"${INDENT}-V, --verbose               Debug logging" \
		"" \
		"${INDENT}-p, --protocol PROTOCOL     Specify which protocol to install:" \
		"                                     ${SUPPORTED_PROTOCOL}" \
		"${INDENT}--enable-now                " \
		""
}

DEFAULT_PROTOCOL="trojan"
SUPPORTED_PROTOCOL="trojan hysteria2"

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
	-V | --verbose)
		VERBOSE=true
		shift 1
		;;
	--enable-now)
		ENABLE_NOW=true
		shift 1
		;;
	*)
		error "Unknown argument: $1"
		usage
		;;
	esac
done

if [[ -z $PROTOCOL ]]; then
	PROTOCOL=$DEFAULT_PROTOCOL
fi

good=$(
	IFS=" "
	for p in $SUPPORTED_PROTOCOL; do
		if [[ "${p}" = "${PROTOCOL}" ]]; then
			printf 1
			break
		fi
	done
)

if [[ "${good}" != "1" ]]; then
	error "$PROTOCOL is not supported yet. Supported protocols: ${SUPPORTED_PROTOCOL}"
	exit 1
fi

# The parent folder of this script.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd ${script_dir}

# Superuser privilege is required.
if [[ $(id -u) -ne 0 ]]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi

XDG_PREFIX_DIR="/usr/local"
SERVICE_DIR="/etc/systemd/system"
SERVICE_NAME="sing-box-${PROTOCOL}.service"
SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}"

set +e
SERVICE_FILES_TO_REMOVE=$(ls $SERVICE_DIR | grep 'sing-box')
if [[ ! -z "${SERVICE_FILES_TO_REMOVE}" ]]; then
	debug "Detected ${INDENT}${SERVICE_FILES_TO_REMOVE}. Stop, disable and remove."
	sudo systemctl stop ${SERVICE_FILES_TO_REMOVE} >/dev/null 2>&1
	sudo systemctl disable ${SERVICE_FILES_TO_REMOVE} >/dev/null 2>&1
	sudo rm ${SERVICE_DIR}/${SERVICE_FILES_TO_REMOVE} >/dev/null 2>&1
fi
set -e

if [[ -f "${script_dir}/${SERVICE_NAME}" ]]; then
	sudo cp "${script_dir}/${SERVICE_NAME}" "${SERVICE_FILE}"
	debug "${script_dir}/${SERVICE_NAME} ${GREEN}${BOLD}->${RESET} ${script_dir}."
else
	error "${script_dir}/${SERVICE_NAME} is not found. Contact your admin."
fi

sudo mkdir -p "${XDG_PREFIX_DIR}/bin"
sudo mkdir -p "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}"
sudo mkdir -p "/var/lib/sing-box/"

if [[ -f "sing-box" ]]; then
	sudo cp ${script_dir}/sing-box "${XDG_PREFIX_DIR}/bin/sing-box"
	debug "${script_dir}/sing-box ${GREEN}${BOLD}->${RESET} ${XDG_PREFIX_DIR}/bin/sing-box"
else
	error "${script_dir}/sing-box is not found."
	exit 1
fi

if [[ -f "${script_dir}/${PROTOCOL}-client.json" ]]; then
	sudo cp "${script_dir}/${PROTOCOL}-client.json" "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
	debug "${script_dir}/${PROTOCOL}-client.json ${GREEN}${BOLD}->${RESET} ${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
elif [[ -f "${script_dir}/${PROTOCOL}-server.json" ]]; then
	sudo cp "${script_dir}/${PROTOCOL}-server.json" "${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
	debug "${script_dir}/${PROTOCOL}-server.json ${GREEN}${BOLD}->${RESET} ${XDG_PREFIX_DIR}/etc/sing-box/${PROTOCOL}/config.json"
fi

debug "Systemd Daemon Reload."
sudo systemctl daemon-reload >/dev/null 2>&1
if [[ "$ENABLE_NOW" == "true" ]]; then
	debug "Systemd Enable Now."
	sudo systemctl enable --now ${SERVICE_NAME} >/dev/null 2>&1
fi

completed "${BOLD}sing-box (${PROTOCOL})${RESET} is successfully installed and managed by systemd from now on.

Try: 
${INDENT}${GREEN}${BOLD}\$${RESET} sudo systemctl status ${SERVICE_NAME}

To use some handy commands:
${INDENT}${GREEN}${BOLD}\$${RESET} source ${script_dir}/setup.bash
${INDENT}${GREEN}${BOLD}\$${RESET} set_proxy
${INDENT}${GREEN}${BOLD}\$${RESET} unset_proxy

You can add 

${INDENT}source ${script_dir}/setup.bash

into ~/.bashrc.
"
