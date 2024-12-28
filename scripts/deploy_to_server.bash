#!/usr/bin/env bash
# Be safe.
set -eo pipefail;
RESET=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)

SERVER_HOSTNAME="$1";
if [[ ! $# -eq 1 ]]; then
    printf "${BOLD}${RED}ERROR: ${RESET}%s\n" "The SSH hostname should be given as an argument."
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
env_file="${script_dir}/../.env"
set -o allexport && source ${env_file} && set +o allexport
RELEASE_DIR="sing-box-v${SING_BOX_VERSION}-${CONFIG_GIT_HASH}"
cd "${script_dir}/../releases/${RELEASE_DIR}"
RELEASE_TAR="sing-box-v${SING_BOX_VERSION}-${CONFIG_GIT_HASH}-server.tar.gz"
if [[ ! -f ${RELEASE_TAR} ]]; then
    printf "${BOLD}${RED}ERROR: ${RESET}%s\n" "${RELEASE_TAR} not found."
    exit 1;
fi

scp ${RELEASE_TAR} "${SERVER_HOSTNAME}:~/";
if [[ ! $? -eq 0 ]]; then
    printf "${BOLD}${RED}ERROR: ${RESET}%s\n" "SCP failed."
    exit 1;
fi
ssh ${SERVER_HOSTNAME} -t "cd ~ && tar -xf ${RELEASE_TAR} && rm ${RELEASE_TAR}" 
if [[ ! $? -eq 0 ]]; then
    printf "${BOLD}${RED}ERROR: ${RESET}%s\n" "Extraction failed."
fi
ssh ${SERVER_HOSTNAME} -t "cd ${RELEASE_DIR}-server/ && sudo ./install.sh"
if [[ ! $? -eq 0 ]]; then
    printf "${BOLD}${RED}ERROR: ${RESET}%s\n" "Install with systemd failed."
fi
ssh ${SERVER_HOSTNAME} -t "sudo systemctl restart sing-box-trojan.service"
