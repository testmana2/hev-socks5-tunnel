#!/bin/sh

set -eu

TUN="${TUN:-tun0}"
MTU="${MTU:-8500}"
IPV4="${IPV4:-198.18.0.1}"
IPV6="${IPV6:-}"
ICMP="${ICMP:-off}"
CONFIG_ROUTES="${CONFIG_ROUTES:-1}"
TABLE="${TABLE:-20}"
if [ "${CONFIG_ROUTES}" = "0" ]; then
  MARK="${MARK:-0}"
else
  MARK="${MARK:-438}"
fi

SOCKS5_ADDR="${SOCKS5_ADDR:-172.17.0.1}"
SOCKS5_PORT="${SOCKS5_PORT:-1080}"
SOCKS5_USERNAME="${SOCKS5_USERNAME:-}"
SOCKS5_PASSWORD="${SOCKS5_PASSWORD:-}"
SOCKS5_UDP_MODE="${SOCKS5_UDP_MODE:-udp}"
SOCKS5_UDP_ADDR="${SOCKS5_UDP_ADDR:-}"
IPV4_INCLUDED_ROUTES="${IPV4_INCLUDED_ROUTES:-0.0.0.0/0}"
IPV4_EXCLUDED_ROUTES="${IPV4_EXCLUDED_ROUTES:-}"

LAN_DNS="${LAN_DNS:-192.168.1.1}"
MAPDNS_ADDRESS="${MAPDNS_ADDRESS:-192.0.2.2}"
MAPDNS_PORT="${MAPDNS_PORT:-53}"
MAPDNS_NETWORK="${MAPDNS_NETWORK:-100.64.0.0}"
MAPDNS_NETMASK="${MAPDNS_NETMASK:-255.192.0.0}"
MAPDNS_CACHE_SIZE="${MAPDNS_CACHE_SIZE:-10000}"
DNS_LISTEN_ADDRESS="${DNS_LISTEN_ADDRESS:-0.0.0.0}"
LOG_LEVEL="${LOG_LEVEL:-warn}"

config_file() {
  cat > /hs5t.yml <<EOF
misc:
  log-level: '${LOG_LEVEL}'
tunnel:
  name: '${TUN}'
  mtu: ${MTU}
  ipv4: '${IPV4}'
  ipv6: '${IPV6}'
  icmp: '${ICMP}'
  post-up-script: '/route.sh'
socks5:
  address: '${SOCKS5_ADDR}'
  port: ${SOCKS5_PORT}
  udp: '${SOCKS5_UDP_MODE}'
  mark: ${MARK}
EOF

  [ -z "${SOCKS5_USERNAME}" ] || echo "  username: '${SOCKS5_USERNAME}'" >> /hs5t.yml
  [ -z "${SOCKS5_PASSWORD}" ] || echo "  password: '${SOCKS5_PASSWORD}'" >> /hs5t.yml
  [ -z "${SOCKS5_UDP_ADDR}" ] || echo "  udp-address: '${SOCKS5_UDP_ADDR}'" >> /hs5t.yml

  cat >> /hs5t.yml <<EOF
mapdns:
  address: '${MAPDNS_ADDRESS}'
  port: ${MAPDNS_PORT}
  network: '${MAPDNS_NETWORK}'
  netmask: '${MAPDNS_NETMASK}'
  cache-size: ${MAPDNS_CACHE_SIZE}
EOF
}

config_dns() {
  cat > /etc/dnsmasq.conf <<EOF
no-resolv
no-hosts
# Keep LAN-only suffixes on the LAN DNS.
server=/local/${LAN_DNS}
server=/lan/${LAN_DNS}
# All other names use hev-socks5-tunnel's mapped DNS.
server=${MAPDNS_ADDRESS}#${MAPDNS_PORT}
listen-address=${DNS_LISTEN_ADDRESS}
bind-interfaces
cache-size=1000
log-facility=-
EOF
}

config_route() {
  echo '#!/bin/sh' > /route.sh
  chmod +x /route.sh
  if [ "${CONFIG_ROUTES}" = "0" ]; then
    return
  fi

  echo "ip route add default dev ${TUN} table ${TABLE}" >> /route.sh
  for addr in $(echo "${IPV4_INCLUDED_ROUTES}" | tr ',' '\n'); do
    [ -n "${addr}" ] && echo "ip rule add to ${addr} table ${TABLE}" >> /route.sh
  done
  echo "ip rule add to $(ip -o -f inet address show eth0 | awk '/scope global/ {print \$4}') table main" >> /route.sh
  for addr in $(echo "${IPV4_EXCLUDED_ROUTES}" | tr ',' '\n'); do
    [ -n "${addr}" ] && echo "ip rule add to ${addr} table main" >> /route.sh
  done
  echo "ip rule add fwmark ${MARK} table main pref 1" >> /route.sh
  echo 'echo 1 > /success' >> /route.sh
}

run() {
  config_file
  config_dns
  config_route
  dnsmasq --keep-in-foreground --conf-file=/etc/dnsmasq.conf &
  DNSMASQ_PID=$!
  trap 'kill "${DNSMASQ_PID}" 2>/dev/null || true' INT TERM EXIT
  exec hev-socks5-tunnel /hs5t.yml
}

run
