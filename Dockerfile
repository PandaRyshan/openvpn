FROM ubuntu:rolling
LABEL maintainer="Hu Xiaohong <xiaohong@duckduck.io>"

ENV VERSION="2.6.5"
ENV URL="https://swupdate.openvpn.org/community/releases/openvpn-${VERSION}.tar.gz"
ENV DEPENDENCIES="libnl-genl-3-dev libcap-ng-dev libssl-dev liblz4-dev \ 
  liblzo2-dev libpam0g-dev libpkcs11-helper1-dev libgcrypt20-dev"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x \
  && apt update && apt install -y build-essential wget easy-rsa pkg-config openssl \
  && apt install --no-install-recommends -y ${DEPENDENCIES} \
  && cd /root && wget -qO- "${URL}" -O openvpn.tar.xz \
  && tar -xf openvpn*.tar.xz && cd openvpn-2.6.5 \
  && ./configure && make && make install && make clean \
  && cd /root && rm -rf openvpn-* && mkdir -p /etc/openvpn/server/ \
  && mkdir easy-rsa && ln -s /usr/share/easy-rsa/* /root/easy-rsa \
  && cd /root/easy-rsa \
  && apt -y remove --autoremove --purge build-essential wget ${DEPENDENCIES} \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root/easy-rsa

COPY ./build-client.sh /root/easy-rsa/build-client.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY ./docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1194
CMD ["openvpn", "/etc/openvpn/openvpn.conf"]
