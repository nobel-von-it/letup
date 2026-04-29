#!/bin/bash

# Configuration and Domains
GITHUB_API="https://api.github.com/meta"
CODEBERG_DOMAINS=("codeberg.org" "v2.codeberg.org")
ARCH_DOMAINS=("aur.archlinux.org" "archlinux.org")
DEFAULT_CONFIG="/etc/amnezia/amneziawg/usa1.conf"

# Metric to identify routes added by this script
METRIC=555

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
    # Only uncomment this if you are sure GitHub is not blocked by your ISP
    curl --connect-timeout 5 --max-time 10 -s "$GITHUB_API" | jq -r '.git[], .web[]' | sort -u | grep -v ":" 2>/dev/null
}

get_github_ips6() {
    curl --connect-timeout 5 --max-time 10 -s "$GITHUB_API" | jq -r '.git[], .web[]' | sort -u | grep ":" 2>/dev/null
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
        if ! ip route show "$ip" 2>/dev/null | grep -q "metric $METRIC"; then
            ip route add "$ip" via "$gw" dev "$dev" metric $METRIC 2>/dev/null
        fi
    else
        # Delete any route to this IP with our metric
        ip route del "$ip" metric $METRIC 2>/dev/null
    fi
}

manage_route6() {
    local ip=$1
    local mode=$2 # add or del
    local gw=$3
    local dev=$4
    
    if [[ -z "$gw" || -z "$dev" ]]; then return; fi

    if [[ "$mode" == "add" ]]; then
        if ! ip -6 route show "$ip" 2>/dev/null | grep -q "metric $METRIC"; then
            ip -6 route add "$ip" via "$gw" dev "$dev" metric $METRIC 2>/dev/null
        fi
    else
        ip -6 route del "$ip" metric $METRIC 2>/dev/null
    fi
}

clean_garbage() {
    echo "Cleaning up all routes with metric $METRIC..."
    # IPv4
    for ip in $(ip route show | grep "metric $METRIC" | awk '{print $1}'); do
        ip route del "$ip" metric $METRIC 2>/dev/null
    done
    # IPv6
    for ip in $(ip -6 route show | grep "metric $METRIC" | awk '{print $1}'); do
        ip -6 route del "$ip" metric $METRIC 2>/dev/null
    done
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

    if [[ "$mode" == "del" ]]; then
        echo "Removing bypass routes..."
        clean_garbage
        return
    fi

    echo "Adding bypass routes via $GW ($DEV)..."
    
    local IPS=""
    IPS+="$(get_github_ips) " 
    IPS+="$(get_codeberg_ips) "
    IPS+="$(get_arch_ips) "
    
    # Fallback if IPS is too short (means APIs failed)
    if [[ ${#IPS} -lt 50 ]]; then
        echo "Warning: API calls failed or returned too few IPs. Using fallback ranges."
        IPS+=" 140.82.112.0/20 192.30.252.0/22 185.199.108.0/22 143.55.64.0/21 217.197.84.140 209.126.35.78 209.126.35.79"
    fi
    
    for ip in $IPS; do
        manage_route "$ip" "add" "$GW" "$DEV"
    done

    local IPS6=""
    # IPS6+="$(get_github_ips6) "
    IPS6+="$(get_codeberg_ips6) "
    IPS6+="$(get_arch_ips6) "
    
    for ip in $IPS6; do
        manage_route6 "$ip" "add" "$GW6" "$DEV6"
    done
    echo "Done."
}

setup() {
    local config=$(realpath ${1:-$DEFAULT_CONFIG})
    local script_path=$(realpath "$0")
    
    if [[ ! -f "$config" ]]; then
        echo "Error: Config file $config not found."
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This command must be run with sudo."
        exit 1
    fi

    echo "Installing bypass hooks to $config..."
    sed -i "/amneziawg-bypass.sh/d" "$config"
    if grep -q "^\[Interface\]" "$config"; then
        sed -i "/^\[Interface\]/a PostUp = $script_path add\nPostDown = $script_path del" "$config"
        echo "Hooks installed. Remember: if GitHub is blocked in your country, do NOT bypass it."
    else
        echo "Error: Could not find [Interface] section."
        exit 1
    fi
}

ACTION=$1
case "$ACTION" in
    add|del)
        run_bypass "$ACTION"
        ;;
    setup)
        setup "$2"
        ;;
    clean)
        clean_garbage
        ;;
    *)
        echo "Usage: $0 {add|del|clean|setup [config_path]}"
        exit 1
        ;;
esac

