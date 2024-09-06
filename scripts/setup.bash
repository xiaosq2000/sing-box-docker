# !/usr/bin/env bash

PROTOCOL=trojan
VERBOSE=false

set -euo pipefail

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

check_public_ip() {
	local ipinfo=$(curl --silent ipinfo.io)
	if [[ -z "$ipinfo" ]]; then
		error "No public networking."
	else
		echo -e "${MAGENTA}Public Network:${RESET}\n${INDENT}$(echo "$ipinfo" | grep --color=never -e '\"ip\"' -e '\"city\"' | sed 's/^[ \t]*//' | awk '{print}' ORS=' ')"
	fi
	echo
}
check_private_ip() {
	echo -e "${MAGENTA}Private Network:${RESET}\n${INDENT}\"ip\": \"$(hostname -I | awk '{ print $1; }')\","
	echo
}

set_proxy() {
	if [[ $(uname -r | grep 'WSL2') ]]; then
		warning "Make sure the VPN client is working on host."
		local host="'$(cat /etc/resolv.conf | grep '^nameserver' | cut -d ' ' -f 2)'"
		local port=1080
	elif [ -f /.dockerenv ]; then
		warning "It's a docker container. only \"host\" networking mode is supported."
		local host="'127.0.0.1'"
		local port=1080
	else
		if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
			local host="'127.0.0.1'"
			local port=1080
			debug "Start the VPN client service."
			sudo systemctl start sing-box-${PROTOCOL}.service
			debug "Set GNOME networking proxy settings."
			dconf write /system/proxy/mode "'manual'"
			dconf write /system/proxy/http/host ${host}
			dconf write /system/proxy/http/port ${port}
			dconf write /system/proxy/https/host ${host}
			dconf write /system/proxy/https/port ${port}
			dconf write /system/proxy/ftp/host ${host}
			dconf write /system/proxy/ftp/port ${port}
			dconf write /system/proxy/socks/host ${host}
			dconf write /system/proxy/socks/port ${port}
			dconf write /system/proxy/ignore-hosts "'localhost,127.0.0.0/8,::1'"
		else
			error "This platform is not supported."
		fi
	fi
	debug "Set environment variables and configure for specific programs."
	local host="${host//\'/}"
	local port="${port}"
	export http_proxy=${http_proxy:-"${host}:${port}"}
	export https_proxy=${https_proxy:-"${host}:${port}"}
	export ftp_proxy=${ftp_proxy:-"${host}:${port}"}
	export socks_proxy=${socks_proxy:-"${host}:${port}"}
	export no_proxy=${no_proxy:-"localhost,127.0.0.0/8,::1"}
	export HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
	export HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
	export FTP_PROXY=${FTP_PROXY:-${ftp_proxy}}
	export SOCKS_PROXY=${SOCKS_PROXY:-${socks_proxy}}
	export NO_PROXY=${NO_PROXY:-${no_proxy}}
	debug "Set git global network proxy."
	git config --global http.proxy ${http_proxy}
	git config --global https.proxy ${https_proxy}
	info "You're recommended to wait a couple of seconds until the VPN client is on.

      Try with:

      ${INDENT}$ VERBOSE=true check_proxy_status

      or

      ${INDENT}$ check_public_ip
    "
}
unset_proxy() {
	if [[ ! $(uname -r | grep 'WSL2') && ! -f /.dockerenv ]]; then
		if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
			debug "Stop VPN client service."
			sudo systemctl stop sing-box-${PROTOCOL}.service
			debug "Unset GNOME networking proxy settings."
			dconf write /system/proxy/mode "'none'"
		else
			error "Unsupported for this platform."
		fi
	fi
	debug "Unset environment variables."
	unset http_proxy
	unset https_proxy
	unset HTTP_PROXY
	unset HTTPS_PROXY
	unset ftp_proxy
	unset FTP_PROXY
	unset socks_proxy
	unset SOCKS_PROXY
	unset all_proxy
	unset ALL_PROXY
	unset no_proxy
	unset NO_PROXY
	debug "Unset git global network proxy."
	git config --global --unset http.proxy
	git config --global --unset https.proxy
	info "Try with:

      ${INDENT}$ VERBOSE=true check_proxy_status

      or

      ${INDENT}$ check_public_ip
    "
}
check_proxy_status() {
	local proxy_env=$(env | grep --color=never -i 'proxy')
	if [[ -n $proxy_env ]]; then
		info "The shell is using network proxy."
	else
		info "The shell is ${BOLD}${YELLOW}NOT${RESET} using network proxy."
	fi
	echo
	check_public_ip
	if [[ $VERBOSE == "true" ]]; then
		echo "${CYAN}Environment Variables Related with Network Proxy: ${RESET}"
		echo $proxy_env | while read line; do echo "${INDENT}${line}"; done
		echo
		echo "${YELLOW}VPN Client Status: ${RESET}"
		if [[ $(uname -r | grep 'WSL2') ]]; then
			warning "Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually."
		elif [[ -f /.dockerenv ]]; then
			warning "Unknown. For a Docker container, the VPN client is probably running on the host machine. Please check manually."
		else
			echo "${INDENT}$(systemctl is-active sing-box-${PROTOCOL}.service)"
		fi
		echo
	fi
}

printf "
${MAGENTA}Avaiable handy commands for networking proxy (protocol: ${PROTOCOL}):${RESET}

${INDENT}${GREEN}${BOLD}\$${RESET} set_proxy
${INDENT}${GREEN}${BOLD}\$${RESET} unset_proxy

${INDENT}${GREEN}${BOLD}\$${RESET} check_private_ip
${INDENT}${GREEN}${BOLD}\$${RESET} check_public_ip
${INDENT}${GREEN}${BOLD}\$${RESET} check_proxy_status

"
