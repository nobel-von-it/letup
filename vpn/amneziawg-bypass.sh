#!/bin/bash
# AmneziaWG Bypass Injector (Paranoid Edition)
# Aim: 110% safe direct routing for Git services

# --- Configuration ---
CONFIG_PATH="${AMNEZIA_CONFIG:-/etc/amnezia/amneziawg/usa1.conf}"
WG_IFACE="${WG_IFACE:-$(basename "${CONFIG_PATH%.conf}")}"
METRIC=555

DOMAINS=(
    "github.com" "api.github.com" "github.io" "raw.githubusercontent.com"
    "codeberg.org" "v2.codeberg.org"
    "aur.archlinux.org" "archlinux.org" "pkgbuild.com"
    "elibrary.ru" "www.elibrary.ru"
    "reddit.com" "www.reddit.com" "old.reddit.com" "out.reddit.com"
    "gql.reddit.com" "gateway.reddit.com" "oauth.reddit.com" "sh.reddit.com"
    "i.redd.it" "v.redd.it" "preview.redd.it" "redd.it"
    "www.redditstatic.com" "redditmedia.com" "styles.redditmedia.com"
    "b.thumbs.redditmedia.com" "a.thumbs.redditmedia.com"
    "ozon.ru" "www.ozon.ru" "m.ozon.ru" "seller.ozon.ru"
    "api.ozon.ru" "api-seller.ozon.ru" "cdn.ozon.ru"
    "travel.ozon.ru" "fresh.ozon.ru" "bank.ozon.ru" "finance.ozon.ru"
    "ozon.st" "www.ozon.st"
)

# Static CIDRs as fallback (GitHub & others)
STATIC_CIDRS=(
    "140.82.112.0/20" "192.30.252.0/22" "185.199.108.0/22" "143.55.64.0/21" # GitHub
    "217.197.84.140/32" # Codeberg
    "95.216.144.15/32"  # AUR
    "195.209.52.65/32" "195.209.52.70/32" # elibrary.ru
    "151.101.1.140/32" "151.101.65.140/32" "151.101.129.140/32" "151.101.193.140/32" # Reddit (Fastly)
    "185.73.192.0/22" "194.9.210.0/23" "31.130.140.0/22" # Ozon & Ozon Bank
)

# --- Internal State ---
REAL_GW=""
REAL_DEV=""
REAL_IP=""

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
        local route_info=$(ip route get "$target" 2>/dev/null | grep -v -E "($WG_IFACE|neth|usa|awg|tun|tap)" | head -n 1)
        REAL_GW=$(echo "$route_info" | awk '{print $3}')
        REAL_DEV=$(echo "$route_info" | awk '{print $5}')
    fi

    if [[ -z "$REAL_GW" || -z "$REAL_DEV" ]]; then
        log "CRITICAL: Physical gateway detection failed. Safety abort."
        return 1
    fi

    # Detect physical IP address
    REAL_IP=$(ip -4 addr show dev "$REAL_DEV" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1)

    # Safety check: is the gateway alive?
    if ! ping -c 1 -W 1 "$REAL_GW" >/dev/null 2>&1; then
        log "WARNING: Gateway $REAL_GW not responding to ping, but we will proceed with caution."
    fi
    return 0
}

resolve_domains() {
    python3 -c "
import socket
import struct
domains = [$(printf "'%s'," "${DOMAINS[@]}")]
ips = set()
for d in domains:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.setsockopt(socket.SOL_SOCKET, 36, struct.pack('I', 51820))
        except: pass
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
    
    # Remove all app and policy bypass rules for torrents (priorities 998 to 1002)
    for prio in 998 999 1000 1001 1002; do
        while ip rule del priority "$prio" 2>/dev/null; do :; done
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

    log "Injecting bypass via $REAL_GW on $REAL_DEV (IP: ${REAL_IP:-unknown})..."

    local all_ips=("${STATIC_CIDRS[@]}")
    
    # Add dynamic IPs
    local resolved=$(resolve_domains)

    if [[ -n "$resolved" ]]; then
        while read -r line; do
            [[ -n "$line" ]] && all_ips+=("$line")
        done <<< "$resolved"
        log "Resolved domains successfully"
    fi

    # Try GitHub Meta API (if GitHub isn't totally blocked yet)
    local gh_meta=$(curl --connect-timeout 2 -s https://api.github.com/meta | jq -r '.git[], .web[]' 2>/dev/null | grep -v ":" | grep -v "localhost")
    if [[ -n "$gh_meta" ]]; then
        while read -r line; do
            [[ -n "$line" ]] && all_ips+=("$line")
        done <<< "$gh_meta"
        log "Fetched GitHub Meta API successfully"
    fi

    local added_count=0
    # Atomic-like route addition
    for ip in $(echo "${all_ips[@]}" | tr ' ' '\n' | sort -u); do
        # We check if IP is valid before adding
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            if ip route add "$ip" via "$REAL_GW" dev "$REAL_DEV" metric $METRIC 2>/dev/null; then
                ((added_count++))
            fi
        fi
    done

    # 1. Interface-level bypass for apps bound to physical dev (SO_BINDTODEVICE)
    ip rule add oif "$REAL_DEV" table main priority 1000 2>/dev/null
    log "Added interface bypass rule for oif $REAL_DEV (priority 1000)"

    # 2. Source IP bypass for incoming replies and sockets bound to physical IP
    if [[ -n "$REAL_IP" ]]; then
        ip rule add from "$REAL_IP" table main priority 999 2>/dev/null
        log "Added source IP bypass rule for from $REAL_IP (priority 999)"
    fi

    # 3. Ingress bypass to prevent asymmetric routing
    ip rule add iif "$REAL_DEV" table main priority 998 2>/dev/null

    # 4. Torrent port bypass (auto-detect from qBittorrent configs or common ports)
    local torrent_ports=()
    for qb_conf in "$HOME/.config/qBittorrent/qBittorrent.conf" /home/*/.config/qBittorrent/qBittorrent.conf; do
        if [[ -f "$qb_conf" ]]; then
            local p=$(grep -i "Session\\\\Port=" "$qb_conf" 2>/dev/null | cut -d= -f2 | tr -d '\r\n')
            [[ -n "$p" ]] && torrent_ports+=("$p")
        fi
    done
    # Add standard torrent listening ports as fallback
    torrent_ports+=(45088 51413 6881)

    for port in $(printf "%s\n" "${torrent_ports[@]}" | sort -u); do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            ip rule add ipproto tcp sport "$port" table main priority 1001 2>/dev/null
            ip rule add ipproto udp sport "$port" table main priority 1001 2>/dev/null
            ip rule add ipproto tcp dport "$port" table main priority 1002 2>/dev/null
            ip rule add ipproto udp dport "$port" table main priority 1002 2>/dev/null
            log "Added port bypass rules for torrent port $port (priorities 1001-1002)"
        fi
    done

    log "Successfully injected $added_count bypass routes."
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
