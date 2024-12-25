FROM ubuntu:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV VERSION="2.6.12"
ENV URL="https://swupdate.openvpn.org/community/releases/openvpn-${VERSION}.tar.gz"
ENV DEPENDENCIES="libnl-genl-3-dev libcap-ng-dev libssl-dev liblz4-dev \ 
  liblzo2-dev libpam0g-dev libpkcs11-helper1-dev libgcrypt20-dev"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x \
  && apt update \
  && apt install -y build-essential iptables curl wget easy-rsa \
    pkg-config openssl expect socat liblzo2-2 libnl-genl-3-200 \
    ${DEPENDENCIES} \
  && cd /root && wget -qO- "${URL}" -O openvpn-${VERSION}.tar.gz \
  && tar -xf openvpn-${VERSION}.tar.gz && cd openvpn-${VERSION} \
  && ./configure && make && make install && make clean \
  && cd /root && rm -rf openvpn-* \
  && apt -y remove build-essential wget ${DEPENDENCIES} \
  && apt autoremove -y \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /etc/openvpn

COPY ./client-gen.sh /client-gen.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY ./docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /wait /client-gen.sh \
  && ln -s /client-gen.sh /usr/local/bin/clientgen

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1194
