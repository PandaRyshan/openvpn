FROM alpine:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV VERSION="2.6.14"
ENV FORWARD_PROXY_IP=""

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ARG TARGETARCH

RUN set -x \
  apk update \
  && apk add --no-cache \
    iptables curl expect socat easy-rsa openvpn \
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
