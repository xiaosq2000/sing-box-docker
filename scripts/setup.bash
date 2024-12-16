#!/usr/bin/env bash

# Script configuration
VERBOSE=${VERBOSE:-false}
PROTOCOL=${PROTOCOL:-trojan}
DEFAULT_PROXY_HOST="127.0.0.1"
DEFAULT_PROXY_PORT=1080
TIMEOUT=10

# Internationalization Support
# Using typeset -A to ensure ZSH compatibility for associative arrays
typeset -A TRANSLATIONS
TRANSLATIONS=(
    ["ERROR"]="错误"
    ["WARNING"]="警告"
    ["INFO"]="日志"
    ["DEBUG"]="调试"
    ["BASHRC_ALREADY_CONFIGURED"]="已配置到.bashrc"
    ["BASHRC_ADDED"]="已添加到.bashrc"
    ["BASHRC_BACKUP_CREATED"]="已创建.bashrc备份"
    ["BASHRC_NOT_FOUND"]="未找到.bashrc文件"
    ["ZSHRC_ALREADY_CONFIGURED"]="已配置到.zshrc"
    ["ZSHRC_ADDED"]="已添加到.zshrc"
    ["ZSHRC_BACKUP_CREATED"]="已创建.zshrc备份"
    ["ZSHRC_NOT_FOUND"]="未找到.zshrc文件"
    ["SCRIPT_NOT_FOUND"]="未找到脚本文件"
    ["SHELL_RC_ADDED"]="已添加到shell配置文件"
    ["NO_SHELL_RC_FOUND"]="未找到shell配置文件"
    ["VPN_STATUS"]="VPN 状态"
    ["PROXY_ENV_VARS"]="代理环境变量"
    ["STOP_VPN"]="停止 VPN 客户端服务"
    ["NETWORK_CHECK_FAILED"]="网络检查失败"
    ["TIMEOUT"]="超时"
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

# Terminal colors with fallback - Bash and ZSH compatible
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        BOLD="$(tput bold 2>/dev/null || echo '')"
        GREY="$(tput setaf 0 2>/dev/null || echo '')"
        RED="$(tput setaf 1 2>/dev/null || echo '')"
        GREEN="$(tput setaf 2 2>/dev/null || echo '')"
        YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
        BLUE="$(tput setaf 4 2>/dev/null || echo '')"
        MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
        RESET="$(tput sgr0 2>/dev/null || echo '')"
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

# Translation function with fallback - Bash and ZSH compatible
translate() {
    local text="$1"
    local language=$(detect_language)

    if [[ "$language" == "zh_CN" ]]; then
        echo "${TRANSLATIONS[$text]:-$text}"
    else
        echo "$text"
    fi
}


# Logging functions - ZSH compatible
error() { printf '%s\n' "${BOLD}${RED}$(translate 'ERROR'):${RESET} $*" >&2; }
warning() { printf '%s\n' "${BOLD}${YELLOW}$(translate 'WARNING'):${RESET} $*"; }
info() { printf '%s\n' "${BOLD}${GREEN}$(translate 'INFO'):${RESET} $*"; }
debug() {
    [[ $VERBOSE == true ]] && printf '%s\n' "${BOLD}${GREY}$(translate 'DEBUG'):${RESET} $*"
}

# Get script path - ZSH compatible
get_script_path() {
    if [ -n "$BASH_VERSION" ]; then
        echo "$(realpath "${BASH_SOURCE[0]}")"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "${${(%):-%x}:A}"
    else
        echo "Unsupported shell type"
        return 1
    fi
}

check_public_ip() {
    local ipinfo=$(curl --silent ipinfo.io)

    if [ $? -ne 0 ] || [ -z "$ipinfo" ]; then
        error "$(translate 'NETWORK_CHECK_FAILED')"
        return 1
    fi

    echo -e "${MAGENTA}$(translate 'Public Network:')${RESET}\n${INDENT}$(echo "$ipinfo" | grep --color=never -e '\"ip\"' -e '\"city\"' | sed 's/^[ \t]*//' | awk '{print}' ORS=' ')"
    return 0
}

check_private_ip() {
    local private_ip
    if ! private_ip=$(hostname -I 2>/dev/null | awk '{ print $1 }'); then
        error "$(translate 'Failed to get private IP')"
        return 1
    fi

    echo -e "${MAGENTA}$(translate 'Private Network:')${RESET}\n${INDENT}\"ip\": \"${private_ip}\","
    return 0
}

# Get proxy configuration based on platform
get_proxy_config() {
    if [[ $(uname -r) =~ WSL2 ]]; then
        eval "$1=$(ip route show | grep -i default | awk '{ print $3}')"
        eval "$2=${DEFAULT_PROXY_PORT}"
        warning "$(translate 'Make sure the VPN client is working on host.')"
    elif [[ -f /.dockerenv ]]; then
        eval "$1=${DEFAULT_PROXY_HOST}"
        eval "$2=${DEFAULT_PROXY_PORT}"
        warning "$(translate "It's a docker container. only \"host\" networking mode is supported.")"
    elif [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]]; then
        eval "$1=${DEFAULT_PROXY_HOST}"
        eval "$2=${DEFAULT_PROXY_PORT}"
    else
        error "$(translate 'This platform is not supported.')"
        return 1
    fi

    return 0
}

has() {
  command -v "$1" 1>/dev/null 2>&1
}

check_port_availability() {
    if [[ -z $1 ]]; then
        error "An argument, the port number, should be given."
        return 1;
    fi
    if has ufw; then
        if [[ $(sudo ufw status | head -n 1 | awk '{ print $2;}') == "active" ]]; then
            info "ufw is active.";
            if [[ -z $(sudo ufw status | grep "$1") ]]; then
                warning "port $1 is not specified in the firewall rules and may not be allowed to use.";
            else
                sudo ufw status | grep "$1"
            fi
        else
            info "ufw is inactive.";
        fi
    fi
    if [[ -z $(sudo lsof -i:$1) ]]; then
        info "port $1 is not in use.";
    else
        error "port $1 is ${BOLD}unavaiable${RESET}.";
    fi
}

# Set proxy configuration
set_proxy() {
    local proxy_host proxy_port
    if ! get_proxy_config proxy_host proxy_port; then
        return 1
    fi

    # Set environment variables
    debug "$(translate 'Set environment variables and configure for specific programs.')"
    export http_proxy="${proxy_host}:${proxy_port}"
    export https_proxy="${proxy_host}:${proxy_port}"
    export ftp_proxy="${proxy_host}:${proxy_port}"
    export socks_proxy="${proxy_host}:${proxy_port}"
    export HTTP_PROXY="${proxy_host}:${proxy_port}"
    export HTTPS_PROXY="${proxy_host}:${proxy_port}"
    export FTP_PROXY="${proxy_host}:${proxy_port}"
    export SOCKS_PROXY="${proxy_host}:${proxy_port}"
    export no_proxy="localhost,127.0.0.0/8,::1"
    export NO_PROXY="${no_proxy}"

    # Configure git proxy
    debug "$(translate 'Set git global network proxy.')"
    if command -v git >/dev/null 2>&1; then
        git config --global http.proxy "http://${proxy_host}:${proxy_port}"
        git config --global https.proxy "http://${proxy_host}:${proxy_port}"
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

# Generic function to configure shell RC files
configure_shell_rc() {
    local rc_file="$1"
    local rc_name="$2"
    local translate_prefix="$3"

    local script_path
    script_path=$(get_script_path) || return 1

    if [[ ! -f "$script_path" ]]; then
        error "$(translate 'SCRIPT_NOT_FOUND')"
        return 1
    fi

    if [[ ! -f "$rc_file" ]]; then
        error "$(translate "${translate_prefix}_NOT_FOUND")"
        return 1
    fi

    # Create backup if it doesn't exist
    local backup="${rc_file}.backup"
    if [[ ! -f "$backup" ]]; then
        cp "$rc_file" "$backup"
        info "$(translate "${translate_prefix}_BACKUP_CREATED"): ${backup}"
    fi

    # Check if source line already exists
    local source_line="source ${script_path}"
    if grep -q "^[[:space:]]*source[[:space:]]*${script_path}" "$rc_file"; then
        return 0
    fi

    # Add newline if the file doesn't end with one
    [[ -s "$rc_file" && -z "$(tail -c1 "$rc_file")" ]] || echo "" >> "$rc_file"

    {
        echo "# Network proxy management configuration"
        echo "$source_line"
        echo ""
    } >> "$rc_file"

    info "$(translate "${translate_prefix}_ADDED"): ${source_line}"

    echo
    info "$(translate 'To apply changes, run:')"
    echo -e "\n${INDENT}$ source ${rc_file}"
}

# Unset proxy configuration
unset_proxy() {
    # Unset environment variables
    debug "$(translate 'Unset environment variables.')"
    unset {http,https,ftp,socks,all,no}_proxy
    unset {HTTP,HTTPS,FTP,SOCKS,ALL,NO}_PROXY

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

    echo $proxy_env
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


# Generic function to configure shell RC files
configure_shell_rc() {
    local rc_file="$1"
    local rc_name="$2"
    local translate_prefix="$3"

    local script_path
    script_path=$(get_script_path) || return 1

    if [[ ! -f "$script_path" ]]; then
        error "$(translate 'SCRIPT_NOT_FOUND')"
        return 1
    fi

    if [[ ! -f "$rc_file" ]]; then
        error "$(translate "${translate_prefix}_NOT_FOUND")"
        return 1
    fi

    # Create backup if it doesn't exist
    local backup="${rc_file}.backup"
    if [[ ! -f "$backup" ]]; then
        cp "$rc_file" "$backup"
        info "$(translate "${translate_prefix}_BACKUP_CREATED"): ${backup}"
    fi

    # Check if source line already exists
    local source_line="[ -f ${script_path} ] && source ${script_path}"
    if grep -q "^[[:space:]]*\[.*\].*&&.*source[[:space:]]*${script_path}" "$rc_file"; then
        return 0
    fi

    # Add newline if the file doesn't end with one
    [[ -s "$rc_file" && -z "$(tail -c1 "$rc_file")" ]] || echo "" >> "$rc_file"

    {
        echo "# Network proxy management configuration"
        echo "$source_line"
        echo ""
    } >> "$rc_file"

    info "$(translate "${translate_prefix}_ADDED"): ${source_line}"

    echo
    info "$(translate 'To apply changes, run:')"
    echo -e "\n${INDENT}$ source ${rc_file}"
}

# Function to configure bashrc
configure_bashrc() {
    configure_shell_rc "${HOME}/.bashrc" "bashrc" "BASHRC"
}

# Function to configure zshrc
configure_zshrc() {
    configure_shell_rc "${HOME}/.zshrc" "zshrc" "ZSHRC"
}

# Function to configure all available shell RC files
configure_shells() {
    local configured=false

    if [[ -f "${HOME}/.bashrc" ]]; then
        configure_bashrc
        configured=true
    fi

    if [[ -f "${HOME}/.zshrc" ]]; then
        configure_zshrc
        configured=true
    fi

    if [[ "$configured" == false ]]; then
        error "$(translate 'NO_SHELL_RC_FOUND')"
        return 1
    fi

    return 0
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

# check_port_availability $DEFAULT_PROXY_PORT
configure_shells
