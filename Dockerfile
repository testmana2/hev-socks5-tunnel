FROM alpine:latest AS builder

RUN apk add --update --no-cache \
    make \
    git \
    gcc \
    linux-headers \
    musl-dev

WORKDIR /src
COPY . /src

RUN make clean && make

FROM alpine:latest
LABEL org.opencontainers.image.source="https://github.com/testmana2/hev-socks5-tunnel"

RUN apk add --update --no-cache \
    iproute2 \
    dnsmasq

ENV TUN=tun0 \
    MTU=8500 \
    IPV4=198.18.0.1 \
    IPV6='' \
    ICMP=off \
    TABLE=20 \
    MARK=438 \
    SOCKS5_ADDR=172.17.0.1 \
    SOCKS5_PORT=1080 \
    SOCKS5_USERNAME='' \
    SOCKS5_PASSWORD='' \
    SOCKS5_UDP_MODE=udp \
    SOCKS5_UDP_ADDR='' \
    CONFIG_ROUTES=1 \
    IPV4_INCLUDED_ROUTES=0.0.0.0/0 \
    IPV4_EXCLUDED_ROUTES='' \
    LAN_DNS=192.168.1.1 \
    MAPDNS_ADDRESS=192.0.2.2 \
    MAPDNS_PORT=53 \
    MAPDNS_NETWORK=100.64.0.0 \
    MAPDNS_NETMASK=255.192.0.0 \
    MAPDNS_CACHE_SIZE=10000 \
    DNS_LISTEN_ADDRESS=0.0.0.0 \
    LOG_LEVEL=warn

HEALTHCHECK --start-period=5s --interval=5s --timeout=2s --retries=3 CMD ["test", "-f", "/success"]

COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh
COPY --from=builder /src/bin/hev-socks5-tunnel /usr/bin/hev-socks5-tunnel

ENTRYPOINT ["/entrypoint.sh"]
