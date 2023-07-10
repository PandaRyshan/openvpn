FROM ubuntu:rolling
LABEL maintainer="Hu Xiaohong <xiaohong@duckduck.io>"

ENV URL="https://github.com/OpenVPN/openvpn/archive/refs/tags/v2.6.5.tar.gz"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker-entrypoint.sh /entrypoint.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait

RUN set -x \
  && apt-get update && apt-get install -y wget build-essential \
  && apt-get install --no-install-recommends -y \
    openssl ca-certificates tar pkg-config libnl-genl-3-dev \
    libcap-ng-dev libssl-dev liblz4-dev liblzo2-dev libpam0g-dev \
    libpkcs11-helper1-dev libgcrypt20-dev \
    certbot python3-certbot-dns-cloudflare cron iptables \
  && wget -qO- "${URL}" -O openvpn.tar.xz \
  && tar xf openvpn.tar.xz && cd openvpn-2.6.5 \
  && ./configure \
  && make && make install && make clean \
  && cd .. && rm -rf openvpn-* \
  && apt-get -y remove --auto-remove --purge wget build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && chmod +x /entrypoint.sh

WORKDIR /etc/openvpn

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["openvpn", "/etc/openvpn/openvpn.conf"]
