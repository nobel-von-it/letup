#!/bin/bash

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
)

# Static CIDRs as fallback (GitHub & others)
STATIC_CIDRS=(
    "140.82.112.0/20" "192.30.252.0/22" "185.199.108.0/22" "143.55.64.0/21" # GitHub
    "217.197.84.140/32" # Codeberg
    "95.216.144.15/32"  # AUR
    "195.209.52.65/32" "195.209.52.70/32" # elibrary.ru
    "151.101.1.140/32" "151.101.65.140/32" "151.101.129.140/32" "151.101.193.140/32" # Reddit (Fastly)
)

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

resolved=$(resolve_domains)

echo $resolved
