FROM alpine:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV VERSION="2.6.14"
ENV FORWARD_PROXY_IP=""
ARG TARGETARCH

RUN apk add --no-cache bash

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

RUN set -x \
  apk upgrade && apk add --no-cache \
    iptables curl expect iproute2 socat easy-rsa openvpn \
  && rm -rf /var/cache/apk/*

WORKDIR /etc/openvpn

COPY ./client-gen.sh /client-gen.sh
COPY ./client-revoke.sh /client-revoke.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY ./docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /wait /client-gen.sh /client-revoke.sh \
  && ln -s /client-gen.sh /usr/local/bin/clientgen \
  && ln -s /client-revoke.sh /usr/local/bin/clientrevoke

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1194

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ss -tln | grep -q ':1194'
