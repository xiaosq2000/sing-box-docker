#!/usr/bin/env bash

# Script configuration
VERBOSE=${VERBOSE:-true}
PROTOCOL=${PROTOCOL:-trojan}
DEFAULT_PROXY_HOST="127.0.0.1"
DEFAULT_PROXY_PORT=1080
TIMEOUT=10

# Internationalization Support
declare -A TRANSLATIONS=(
    # Original translations preserved...
    ["ERROR"]="错误"
    ["WARNING"]="警告"
    ["INFO"]="信息"
    ["DEBUG"]="调试"

    ["or"]="或者"
    
    # Added new translations
    ["VPN_STATUS"]="VPN 状态"
    ["PROXY_ENV_VARS"]="代理环境变量"
    ["STOP_VPN"]="停止 VPN 客户端服务"
    ["NETWORK_CHECK_FAILED"]="网络检查失败"
    ["TIMEOUT"]="超时"
    
    # Original translations preserved...
    ["Public Network:"]="公共网络："
    ["Private Network:"]="私有网络："
    ["No public networking."]="无公共网络。"
    ["This platform is not supported."]="不支持此平台。"
    ["Make sure the VPN client is working on host."]="确保 VPN 客户端在主机上正常工作。"
    ["Start the VPN client service."]="启动 VPN 客户端服务。"
    ["Set GNOME networking proxy settings."]="设置 GNOME 网络代理设置。"
    ["Unset GNOME networking proxy settings."]="取消 GNOME 网络代理"
    ["Set environment variables and configure for specific programs."]="设置环境变量并配置特定程序。"
    ["Unset environment variables."]="取消环境变量"
    ["Set git global network proxy."]="设置 Git 全局网络代理。"
    ["Unset git global network proxy."]="取消 Git 全局网络代理"
    ["The shell is using network proxy."]="Shell 正在使用网络代理。"
    ["The shell is NOT using network proxy."]="Shell 未使用网络代理。"
    ["Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually."]="未知。对于 WSL2，VPN 客户端可能在主机上运行。请手动检查。"
    ["Done!"]="成功！"
    ["If not working, wait a couple of seconds."]="若未正常启动，稍等几秒后再尝试上网。"
    ["If still not working, you are suggested to execute following commands to print log and ask for help."]="若始终无法正常使用，请执行如下指令获取日志，寻求技术支持。"
    ["Available handy commands for networking proxy"]="网络代理相关的快捷命令："
)

# Terminal colors with fallback
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        BOLD="$(tput bold 2>/dev/null || printf '')"
        GREY="$(tput setaf 0 2>/dev/null || printf '')"
        RED="$(tput setaf 1 2>/dev/null || printf '')"
        GREEN="$(tput setaf 2 2>/dev/null || printf '')"
        YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
        BLUE="$(tput setaf 4 2>/dev/null || printf '')"
        MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
        RESET="$(tput sgr0 2>/dev/null || printf '')"
    else
        BOLD=""
        GREY=""
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        MAGENTA=""
        RESET=""
    fi
}

# Detect system locale
detect_language() {
    local lang=${LANG:-en_US.UTF-8}
    case "$lang" in
        zh_CN* | zh_SG*) echo "zh_CN" ;;
        *) echo "en_US" ;;
    esac
}

# Translation function with fallback
translate() {
    local text="$1"
    local language=$(detect_language)

    if [[ "$language" == "zh_CN" ]]; then
        echo "${TRANSLATIONS[$text]:-$text}"
    else
        echo "$text"
    fi
}

# Logging functions
error() { printf '%s\n' "${BOLD}${RED}$(translate 'ERROR'):${RESET} $*" >&2; }
warning() { printf '%s\n' "${BOLD}${YELLOW}$(translate 'WARNING'):${RESET} $*"; }
info() { printf '%s\n' "${BOLD}${GREEN}$(translate 'INFO'):${RESET} $*"; }
debug() {
    [[ $VERBOSE == true ]] && printf '%s\n' "${BOLD}${GREY}$(translate 'DEBUG'):${RESET} $*"
}

# Network check with timeout
check_public_ip() {
    local timeout_cmd
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout ${TIMEOUT}"
    else
        timeout_cmd=""
        warning "$(translate 'Command timeout not found, network checks might hang')"
    fi
    
    local ipinfo
    if ! ipinfo=$(${timeout_cmd} curl --silent --max-time "${TIMEOUT}" ipinfo.io); then
        error "$(translate 'NETWORK_CHECK_FAILED')"
        return 1
    fi
    
    if [[ -z "$ipinfo" ]]; then
        error "$(translate 'No public networking.')"
        return 1
    fi
    
    echo -e "${MAGENTA}$(translate 'Public Network:')${RESET}\n${INDENT}$(echo "$ipinfo" | grep --color=never -e '\"ip\"' -e '\"city\"' | sed 's/^[ \t]*//' | awk '{print}' ORS=' ')"
    echo
    return 0
}

check_private_ip() {
    local private_ip
    if ! private_ip=$(hostname -I 2>/dev/null | awk '{ print $1 }'); then
        error "$(translate 'Failed to get private IP')"
        return 1
    fi
    
    echo -e "${MAGENTA}$(translate 'Private Network:')${RESET}\n${INDENT}\"ip\": \"${private_ip}\","
    echo
    return 0
}

# Get proxy configuration based on platform
get_proxy_config() {
    local -n host=$1
    local -n port=$2
    
    if [[ $(uname -r) =~ WSL2 ]]; then
        host="$(ip route show | grep -i default | awk '{ print $3}')"
        port="${DEFAULT_PROXY_PORT}"
        warning "$(translate 'Make sure the VPN client is working on host.')"
    elif [[ -f /.dockerenv ]]; then
        host="${DEFAULT_PROXY_HOST}"
        port="${DEFAULT_PROXY_PORT}"
        warning "$(translate "It's a docker container. only \"host\" networking mode is supported.")"
    elif [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]]; then
        host="${DEFAULT_PROXY_HOST}"
        port="${DEFAULT_PROXY_PORT}"
    else
        error "$(translate 'This platform is not supported.')"
        return 1
    fi
    
    return 0
}

# Set proxy configuration
set_proxy() {
    local proxy_host proxy_port
    if ! get_proxy_config proxy_host proxy_port; then
        return 1
    fi
    
    # Set environment variables
    debug "$(translate 'Set environment variables and configure for specific programs.')"
    export {http,https,ftp,socks}_proxy="${proxy_host}:${proxy_port}"
    export {HTTP,HTTPS,FTP,SOCKS}_PROXY="${proxy_host}:${proxy_port}"
    export no_proxy="localhost,127.0.0.0/8,::1"
    export NO_PROXY="${no_proxy}"
    
    # Configure git proxy
    debug "$(translate 'Set git global network proxy.')"
    if command -v git >/dev/null 2>&1; then
        git config --global http.proxy "${http_proxy}"
        git config --global https.proxy "${https_proxy}"
    fi
    
    # Configure GNOME proxy if applicable
    if [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]] && command -v dconf >/dev/null 2>&1; then
        debug "$(translate 'Set GNOME networking proxy settings.')"
        dconf write /system/proxy/mode "'manual'"
        for protocol in http https ftp socks; do
            dconf write "/system/proxy/${protocol}/host" "'${proxy_host}'"
            dconf write "/system/proxy/${protocol}/port" "${proxy_port}"
        done
        dconf write /system/proxy/ignore-hosts "'${no_proxy}'"
    fi
    info "$(translate 'Done!')"
    info "$(translate 'If not working, wait a couple of seconds.')"
    info "$(translate 'If still not working, you are suggested to execute following commands to print log and ask for help.')"
    echo -e "${INDENT}${GREEN}${BOLD}\$${RESET} VERBOSE=true check_proxy_status \n${INDENT}${GREEN}${BOLD}\$${RESET} check_public_ip"
}

# Unset proxy configuration
unset_proxy() {
    # Unset environment variables
    debug "$(translate 'Unset environment variables.')"
    unset {http,https,ftp,socks,all}_proxy
    unset {HTTP,HTTPS,FTP,SOCKS,ALL}_PROXY
    unset {no,NO}_PROXY
    
    # Unset git proxy configuration
    debug "$(translate 'Unset git global network proxy.')"
    if command -v git >/dev/null 2>&1; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    fi
    
    # Reset GNOME proxy if applicable
    if [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]] && command -v dconf >/dev/null 2>&1; then
        debug "$(translate 'Unset GNOME networking proxy settings.')"
        dconf write /system/proxy/mode "'none'"
    fi

    info "$(translate 'Done!')"
}

# Check proxy status
check_proxy_status() {
    local proxy_env
    proxy_env=$(env | grep -i proxy)
    
    if [[ -n $proxy_env ]]; then
        info "$(translate 'The shell is using network proxy.')"
    else
        info "$(translate 'The shell is NOT using network proxy.')"
    fi
    echo
    
    check_public_ip
    
    if [[ $VERBOSE == true ]]; then
        echo "$(translate 'PROXY_ENV_VARS'):"
        echo "$proxy_env" | while read -r line; do 
            echo "${INDENT}${line}"
        done
        echo
        
        echo -e "$(translate 'VPN_STATUS'): ${RESET}"
        if [[ $(uname -r) =~ WSL2 ]]; then
            warning "$(translate 'Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually.')"
        elif [[ -f /.dockerenv ]]; then
            warning "$(translate 'Unknown. For a Docker container, the VPN client is probably running on the host machine. Please check manually.')"
        elif command -v systemctl >/dev/null 2>&1; then
            echo "${INDENT}$(systemctl is-active "sing-box-${PROTOCOL}.service")"
        else
            warning "$(translate 'Cannot determine VPN status - systemctl not available')"
        fi
        echo
    fi
}

# Main script initialization
setup_colors
INDENT='    '

# Show available commands
echo "$(translate "Available handy commands for networking proxy")"
echo "${INDENT}${GREEN}${BOLD}\$${RESET} set_proxy"
echo "${INDENT}${GREEN}${BOLD}\$${RESET} unset_proxy"
echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_private_ip"
echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_public_ip"
echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_proxy_status"
