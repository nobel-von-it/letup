#!/bin/bash
# Clean up existing bypass routes manually

echo "Checking for bypass routes to clean..."

# Detect default gateway
GW=$(ip route show default | grep -v "usa1" | awk '/default/ {print $3}' | head -n 1)
DEV=$(ip route show default | grep -v "usa1" | awk '/default/ {print $5}' | head -n 1)

if [[ -z "$GW" || -z "$DEV" ]]; then
    echo "Could not detect default gateway. Please check your connection."
    exit 1
fi

echo "Detected default gateway: $GW on $DEV"

# Function to delete a route safely
del_route() {
    local ip=$1
    if ip route show "$ip" 2>/dev/null | grep -q "$DEV"; then
        echo "Deleting route: $ip"
        sudo ip route del "$ip" via "$GW" dev "$DEV" 2>/dev/null
    fi
}

# 1. Known Codeberg IPs
CODEBERG_IPS=("217.197.84.140" "209.126.35.78" "209.126.35.79")
for ip in "${CODEBERG_IPS[@]}"; do
    del_route "$ip"
done

# 2. Arch Linux IPs
ARCH_DOMAINS=("aur.archlinux.org" "archlinux.org")
for domain in "${ARCH_DOMAINS[@]}"; do
    # Use python for quick DNS check, timeout 2s
    ips=$(python3 -c "import socket; socket.setdefaulttimeout(2); [print(i[4][0]) for i in socket.getaddrinfo('$domain', 80, socket.AF_INET)]" 2>/dev/null)
    for ip in $ips; do
        del_route "$ip"
    done
done

# 3. GitHub IPs (Try fetching with timeout, otherwise skip)
echo "Attempting to fetch GitHub IPs (timeout 5s)..."
GITHUB_IPS=$(curl --connect-timeout 5 --max-time 10 -s "https://api.github.com/meta" | jq -r '.git[], .web[]' 2>/dev/null | sort -u | grep -v ":")

if [[ -n "$GITHUB_IPS" ]]; then
    for ip in $GITHUB_IPS; do
        del_route "$ip"
    done
else
    echo "GitHub API unreachable, skipping dynamic cleanup. Using fallback ranges..."
    # Fallback common GitHub ranges
    FALLBACK_GITHUB=("140.82.112.0/20" "192.30.252.0/22" "185.199.108.0/22" "143.55.64.0/21")
    for range in "${FALLBACK_GITHUB[@]}"; do
        del_route "$range"
    done
fi

# 4. Aggressive cleanup: any host route via the local gateway
echo "Searching for remaining 'garbage' host routes via $GW..."
GARBAGE=$(ip route show | grep "via $GW" | grep -v "default" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
for ip in $GARBAGE; do
    echo "Found garbage IPv4: $ip"
    del_route "$ip"
done

# IPv6 Aggressive cleanup
GW6=$(ip -6 route show default | grep -v "usa1" | awk '/default/ {print $3}' | head -n 1)
DEV6=$(ip -6 route show default | grep -v "usa1" | awk '/default/ {print $5}' | head -n 1)
if [[ -n "$GW6" ]]; then
    echo "Searching for remaining 'garbage' IPv6 host routes via $GW6..."
    GARBAGE6=$(ip -6 route show | grep "via $GW6" | grep -v "default" | awk '{print $1}')
    for ip in $GARBAGE6; do
        echo "Found garbage IPv6: $ip"
        sudo ip -6 route del "$ip" via "$GW6" dev "$DEV6" 2>/dev/null
    done
fi

echo "Cleanup finished."
ip route show | grep "via $GW" | grep -v "default"
