#!/bin/bash

# Configuration and Domains
GITHUB_API="https://api.github.com/meta"
CODEBERG_DOMAINS=("codeberg.org" "v2.codeberg.org")
ARCH_DOMAINS=("aur.archlinux.org" "archlinux.org")
DEFAULT_CONFIG="/etc/amnezia/amneziawg/usa1.conf"

# Detection of default gateway and interface
get_default_gw() {
    ip route show default | grep -v "usa1" | awk '/default/ {print $3}' | head -n 1
}

get_default_dev() {
    ip route show default | grep -v "usa1" | awk '/default/ {print $5}' | head -n 1
}

get_default_gw6() {
    ip -6 route show default | grep -v "usa1" | awk '/default/ {print $3}' | head -n 1
}

get_default_dev6() {
    ip -6 route show default | grep -v "usa1" | awk '/default/ {print $5}' | head -n 1
}

# Fetch GitHub IPs
get_github_ips() {
    curl -s "$GITHUB_API" | jq -r '.git[], .web[]' | sort -u | grep -v ":"
}

get_github_ips6() {
    curl -s "$GITHUB_API" | jq -r '.git[], .web[]' | sort -u | grep ":"
}

# Resolve Codeberg IPs using Python for reliability
get_codeberg_ips() {
    for domain in "${CODEBERG_DOMAINS[@]}"; do
        python3 -c "import socket; [print(i[4][0]) for i in socket.getaddrinfo('$domain', 80, socket.AF_INET)]" 2>/dev/null
    done | sort -u
}

get_codeberg_ips6() {
    for domain in "${CODEBERG_DOMAINS[@]}"; do
        python3 -c "import socket; [print(i[4][0]) for i in socket.getaddrinfo('$domain', 80, socket.AF_INET6)]" 2>/dev/null
    done | sort -u
}

get_arch_ips() {
    for domain in "${ARCH_DOMAINS[@]}"; do
        python3 -c "import socket; [print(i[4][0]) for i in socket.getaddrinfo('$domain', 80, socket.AF_INET)]" 2>/dev/null
    done | sort -u
}

get_arch_ips6() {
    for domain in "${ARCH_DOMAINS[@]}"; do
        python3 -c "import socket; [print(i[4][0]) for i in socket.getaddrinfo('$domain', 80, socket.AF_INET6)]" 2>/dev/null
    done | sort -u
}

manage_route() {
    local ip=$1
    local mode=$2 # add or del
    local gw=$3
    local dev=$4
    
    if [[ "$mode" == "add" ]]; then
        if ! ip route show "$ip" 2>/dev/null | grep -q "$dev"; then
            ip route add "$ip" via "$gw" dev "$dev" 2>/dev/null
        fi
    else
        ip route del "$ip" via "$gw" dev "$dev" 2>/dev/null
    fi
}

manage_route6() {
    local ip=$1
    local mode=$2 # add or del
    local gw=$3
    local dev=$4
    
    if [[ -z "$gw" || -z "$dev" ]]; then return; fi

    if [[ "$mode" == "add" ]]; then
        if ! ip -6 route show "$ip" 2>/dev/null | grep -q "$dev"; then
            ip -6 route add "$ip" via "$gw" dev "$dev" 2>/dev/null
        fi
    else
        ip -6 route del "$ip" via "$gw" dev "$dev" 2>/dev/null
    fi
}

run_bypass() {
    local mode=$1
    local GW=$(get_default_gw)
    local DEV=$(get_default_dev)
    local GW6=$(get_default_gw6)
    local DEV6=$(get_default_dev6)

    if [[ -z "$GW" || -z "$DEV" ]]; then
        echo "Error: Could not detect default gateway or interface."
        exit 1
    fi

    echo "Running $mode for bypass routes..."

    # IPv4
    IPS=$(get_github_ips)
    IPS+=" $(get_codeberg_ips)"
    IPS+=" $(get_arch_ips)"
    for ip in $IPS; do
        manage_route "$ip" "$mode" "$GW" "$DEV"
    done

    # IPv6
    IPS6=$(get_github_ips6)
    IPS6+=" $(get_codeberg_ips6)"
    IPS6+=" $(get_arch_ips6)"
    for ip in $IPS6; do
        manage_route6 "$ip" "$mode" "$GW6" "$DEV6"
    done
    echo "Done."
}

setup() {
    local config=$(realpath ${1:-$DEFAULT_CONFIG})
    local script_path=$(realpath "$0")
    
    if [[ ! -f "$config" ]]; then
        echo "Error: Config file $config not found. Please specify it: $0 setup /path/to/your.conf"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This command must be run with sudo."
        exit 1
    fi

    echo "Installing bypass hooks to $config..."
    
    # 1. Clean up old entries
    sed -i "/amneziawg-bypass.sh/d" "$config"
    
    # 2. Insert after [Interface]
    if grep -q "^\[Interface\]" "$config"; then
        sed -i "/^\[Interface\]/a PostUp = $script_path add\nPostDown = $script_path del" "$config"
        echo "Successfully installed hooks."
    else
        echo "Error: Could not find [Interface] section in $config."
        exit 1
    fi
    
    echo "--------------------------------------------------------"
    echo "Setup complete. To apply changes now, restart your VPN:"
    echo "  sudo awg-quick down $(basename "$config" .conf)"
    echo "  sudo awg-quick up $(basename "$config" .conf)"
    echo "--------------------------------------------------------"
}

ACTION=$1
case "$ACTION" in
    add|del)
        run_bypass "$ACTION"
        ;;
    setup)
        setup "$2"
        ;;
    *)
        echo "Usage: $0 {add|del|setup [config_path]}"
        echo "Example: sudo $0 setup"
        exit 1
        ;;
esac
