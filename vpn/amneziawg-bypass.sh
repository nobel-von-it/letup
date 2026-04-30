#!/bin/bash
# AmneziaWG Bypass Injector (Paranoid Edition)
# Aim: 110% safe direct routing for Git services

# --- Configuration ---
WG_IFACE="usa1"
METRIC=555
CONFIG_PATH="/etc/amnezia/amneziawg/usa1.conf"

DOMAINS=(
    "github.com" "api.github.com" "github.io" "raw.githubusercontent.com"
    "codeberg.org" "v2.codeberg.org"
    "aur.archlinux.org" "archlinux.org" "pkgbuild.com"
)

# Static CIDRs as fallback (GitHub & others)
STATIC_CIDRS=(
    "140.82.112.0/20" "192.30.252.0/22" "185.199.108.0/22" "143.55.64.0/21" # GitHub
    "217.197.84.140/32" # Codeberg
    "95.216.144.15/32"  # AUR
)

# --- Internal State ---
REAL_GW=""
REAL_DEV=""

log() {
    echo "[Bypass] $1"
    logger -t amneziawg-bypass "$1"
}

# 110% Safe tool check
check_requirements() {
    for tool in ip awk python3 jq curl ping; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log "ERROR: Required tool '$tool' is missing. Aborting for safety."
            exit 1
        fi
    done
}

# Find physical gateway with 200% reliability
get_real_networking() {
    # Method 1: Look at the 'main' table default gateway (most reliable)
    local main_gw_info=$(ip route show table main default | head -n 1)
    REAL_GW=$(echo "$main_gw_info" | awk '{print $3}')
    REAL_DEV=$(echo "$main_gw_info" | awk '{print $5}')

    # Method 2: Fallback to 'ip route get' if main table is empty
    if [[ -z "$REAL_GW" || -z "$REAL_DEV" ]]; then
        local target="8.8.8.8"
        local route_info=$(ip route get "$target" | grep -v "$WG_IFACE" | head -n 1)
        REAL_GW=$(echo "$route_info" | awk '{print $3}')
        REAL_DEV=$(echo "$route_info" | awk '{print $5}')
    fi

    if [[ -z "$REAL_GW" || -z "$REAL_DEV" ]]; then
        log "CRITICAL: Physical gateway detection failed. Safety abort."
        return 1
    fi

    # Safety check: is the gateway alive?
    if ! ping -c 1 -W 1 "$REAL_GW" >/dev/null 2>&1; then
        log "WARNING: Gateway $REAL_GW not responding to ping, but we will proceed with caution."
    fi
    return 0
}

resolve_domains() {
    python3 -c "
import socket
domains = [$(printf "'%s'," "${DOMAINS[@]}")]
ips = set()
for d in domains:
    try:
        infos = socket.getaddrinfo(d, 80, socket.AF_INET)
        for i in infos: ips.add(i[4][0])
    except: pass
print('\n'.join(ips))
"
}

# --- Main Logic ---

del_routes() {
    log "Cleaning up routes (Metric $METRIC)..."
    # Mass deletion of any route with our specific metric
    ip route show | grep "metric $METRIC" | awk '{print $1}' | while read -r ip; do
        ip route del "$ip" metric $METRIC 2>/dev/null
    done
    log "Cleanup complete."
}

add_routes() {
    check_requirements
    
    # Always clean before adding to prevent duplicates/conflicts
    del_routes

    if ! get_real_networking; then
        exit 1
    fi

    log "Injecting bypass via $REAL_GW on $REAL_DEV..."

    local all_ips=("${STATIC_CIDRS[@]}")
    
    # Add dynamic IPs
    local resolved=$(resolve_domains)
    if [[ -n "$resolved" ]]; then all_ips+=($resolved); fi
    
    # Try GitHub Meta API (if GitHub isn't totally blocked yet)
    local gh_meta=$(curl --connect-timeout 2 -s https://api.github.com/meta | jq -r '.git[], .web[]' 2>/dev/null | grep -v ":")
    if [[ -n "$gh_meta" ]]; then all_ips+=($gh_meta); fi

    # Atomic-like route addition
    for ip in $(echo "${all_ips[@]}" | tr ' ' '\n' | sort -u); do
        # We check if IP is valid before adding
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            ip route add "$ip" via "$REAL_GW" dev "$REAL_DEV" metric $METRIC 2>/dev/null
        fi
    done

    log "Successfully injected $(echo "${all_ips[@]}" | wc -w) bypass routes."
}

# --- Installation ---

setup() {
    check_requirements
    local config="${1:-$CONFIG_PATH}"
    local script_path=$(realpath "$0")
    
    if [[ ! -f "$config" ]]; then
        log "ERROR: Config $config not found."
        exit 1
    fi
    
    # Remove existing lines and add fresh ones
    sed -i "/amneziawg-bypass.sh/d" "$config"
    if grep -q "^\[Interface\]" "$config"; then
        sed -i "/^\[Interface\]/a PostUp = $script_path add\nPostDown = $script_path del" "$config"
        log "Hooks installed successfully to $config."
    else
        log "ERROR: Could not find [Interface] section in config."
        exit 1
    fi
}

# --- Execution ---
case "$1" in
    add) add_routes ;;
    del) del_routes ;;
    setup) setup "$2" ;;
    *) echo "Usage: $0 {add|del|setup}"; exit 1 ;;
esac
