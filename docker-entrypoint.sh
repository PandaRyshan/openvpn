#!/bin/bash

# Wait for other container
# /wait

################################
# WORKDIR /etc/openvpn
################################
mkdir -p /etc/openvpn/certs /etc/openvpn/server /etc/openvpn/clients
cd /etc/openvpn/certs

if [ ! -f vars ]; then
	echo "vars not found, copying..."
	cp /usr/share/easy-rsa/vars.example ./vars
fi

# Init PKI
if [ ! -d "/etc/openvpn/certs/pki" ]; then
	echo "default pki not found, init pki"
	echo yes | /usr/share/easy-rsa/easyrsa init-pki
fi

# Build CA
if [ ! -f "/etc/openvpn/certs/pki/ca.crt" ]; then
	echo "default ca.crt not found, creating..."
	if [ -z "$DEFAULT_CA_PASSPHRASE" ]; then
		echo "DEFAULT_PASSPHRASE not found, creating..."
		DEFAULT_CA_PASSPHRASE=$(openssl rand -base64 14)
		echo -e "$DEFAULT_CA_PASSPHRASE" > /etc/openvpn/certs/pki/DEFAULT_CA_PASSPHRASE
	fi
	/usr/bin/expect << EOF
spawn /usr/share/easy-rsa/easyrsa build-ca
expect "Enter New CA Key Passphrase"
send "$DEFAULT_CA_PASSPHRASE\r"
expect "Confirm New CA Key Passphrase"
send "$DEFAULT_CA_PASSPHRASE\r"
expect "Common Name (eg: your user, host, or server name)"
send "\r"
expect eof
EOF
	# echo -e "$DEFAULT_CA_PASSPHRASE\n$DEFAULT_CA_PASSPHRASE\n" | /usr/share/easy-rsa/easyrsa build-ca
	if [ ! -f "/etc/openvpn/server/ca.crt" ]; then
		cp /etc/openvpn/certs/pki/ca.crt /etc/openvpn/server/
	fi
fi

# Build Server crt
if [ ! -f "/etc/openvpn/certs/pki/issued/server.crt" ]; then
	echo "default server.crt not found, creating..."
	/usr/bin/expect << EOF
spawn /usr/share/easy-rsa/easyrsa --days=3650 build-server-full server nopass
expect "Confirm request details"
send "yes\r"
expect "Enter pass phrase for"
send "$DEFAULT_CA_PASSPHRASE\r"
expect eof
EOF
	if [ ! -f "/etc/openvpn/server/server.crt" ]; then
		cp /etc/openvpn/certs/pki/issued/server.crt /etc/openvpn/server/
		cp /etc/openvpn/certs/pki/private/server.key /etc/openvpn/server/
	fi
fi

# Build tls auth/crypt key
if [ ! -f "/etc/openvpn/certs/pki/ta.key" ]; then
	echo "default ta.key not found, creating..."
	openvpn --genkey secret /etc/openvpn/certs/pki/ta.key
	if [ ! -f "/etc/openvpn/server/ta.key" ]; then
		cp /etc/openvpn/certs/pki/ta.key /etc/openvpn/server/
	fi
fi

# Build DH
if [ ! -f "/etc/openvpn/certs/pki/dh.pem" ]; then
	echo "default dh.pem not found, createing..."
	/usr/share/easy-rsa/easyrsa gen-dh
	if [ ! -f "/etc/openvpn/server/dh.pem" ]; then
		cp /etc/openvpn/certs/pki/dh.pem /etc/openvpn/server/
	fi
fi

# Build CRL
if [ ! -f "/etc/openvpn/certs/pki/crl.pem" ]; then
	echo "default crl.pem not found, creating..."
	/usr/bin/expect << EOF
spawn /usr/share/easy-rsa/easyrsa gen-crl
expect "Enter pass phrase for"
send "$DEFAULT_CA_PASSPHRASE\r"
expect eof
EOF
	if [ ! -f "/etc/openvpn/server/crl.pem" ]; then
		cp /etc/openvpn/certs/pki/crl.pem /etc/openvpn/server/
	fi
fi

if [ "$PROTO" == "udp" ]; then
	PROTO_SERVER="udp"
	PROTO_CLIENT="udp"
else
	PROTO_SERVER="tcp-server"
	PROTO_CLIENT="tcp-client"
fi

# Build server config
# if you want a tcp server, set: proto tcp-server
if [ ! -f "/etc/openvpn/server/server.conf" ]; then
	echo "server.conf not found, creating..."
	touch /etc/openvpn/server/server.conf
	cat <<- EOF > /etc/openvpn/server/server.conf
verify-client-cert
key-direction 0
duplicate-cn
port 1194
proto ${PROTO_SERVER}
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
auth SHA256
tls-crypt /etc/openvpn/server/ta.key
tls-version-min 1.3
crl-verify /etc/openvpn/server/crl.pem
topology subnet
server 192.168.199.0 255.255.255.0
server-ipv6 2001:db8:2::/64
# ifconfig-pool <start-ip> <end-ip>
# ifconfig-ipv6-pool <start-ip> <end-ip>
push "redirect-gateway def1 bypass-dhcp"
push "redirect-gateway ipv6"
push "route-ipv6 2000::/3"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
verb 3
# explicit-exit-notify only used in UDP mode
# explicit-exit-notify
EOF
fi

# Build client base config
if [ -n "$DOMAIN" ]; then
	DOMAIN_OR_IP=$DOMAIN
else
	IPV4=$(timeout 3 curl -s https://ipinfo.io/ip)
	IPV6=$(timeout 3 curl -s https://6.ipinfo.io/ip)
	DOMAIN_OR_IP=${IPV4:-$IPV6}
fi

if [ -z "$PORT" ]; then
	PORT=443
fi

if [ ! -f "/etc/openvpn/clients/base.conf" ]; then
	echo "base.conf not found, creating..."
	touch /etc/openvpn/clients/base.conf
	cat <<- EOF > /etc/openvpn/clients/base.conf
client
dev tun
proto ${PROTO_CLIENT}
remote ${DOMAIN_OR_IP} ${PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
tls-version-min 1.3
auth SHA256
key-direction 1
verb 3
EOF
	clientgen
fi

# Enable NAT forwarding
echo "Forwarding IP..."
iptables -t nat -A POSTROUTING -s 192.168.199.0/24 -o eth0 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s 2001:db8:2::/64 -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

## TODO: 加入对域名的支持，可以通过域名直接得到 ipv4 和 ipvk
if [ -n "$FORWARD_PROXY_IPV4" ]; then
	echo "Detected FORWARD_PROXY_IPV4=$FORWARD_PROXY_IPV4, applying iptables DNAT rule..."
	iptables -t nat -A PREROUTING -i tun0 -p tcp -m multiport --dports 80,443 \
		-j DNAT --to-destination "$FORWARD_PROXY_IPV4"
else
	echo "No FORWARD_PROXY_IPV4 set. Skipping DNAT rules."
fi
if [ -n "$FORWARD_PROXY_IPV6" ]; then
	echo "Detected FORWARD_PROXY_IPV6=$FORWARD_PROXY_IPV6, applying iptables DNAT rule..."
	ip6tables -t nat -A PREROUTING -i tun0 -p tcp -m multiport --dports 80,443 \
		-j DNAT --to-destination "$FORWARD_PROXY_IPV6"
else
	echo "No FORWARD_PROXY_IPV6 set. Skipping DNAT rules."
fi

## TODO: 需要改进对 gost 的支持
if timeout 1 getent hosts gost > /dev/null 2>&1; then
	echo "Detected gost service, setting up proxy forwarding..."
	PROXY_IPV4=$(getent ahostsv4 gost | head -n 1 | awk '{print $1}')
	PROXY_IPV6=$(getent ahostsv6 gost | head -n 1 | awk '{print $1}')

	if [ -n "$PROXY_IPV4" ]; then
		iptables -t nat -A PREROUTING -i tun0 -p tcp -m multiport --dports 80,443 \
			-j DNAT --to-destination "$PROXY_IPV4:40000"
		echo "IPv4 Forwarded to gost"
	fi
	if [ -n "$PROXY_IPV6" ]; then
		ip6tables -t nat -A PREROUTING -i tun0 -p tcp -m multiport --dports 80,443 \
			-j DNAT --to-destination "[$PROXY_IPV6]:40000"
		echo "IPv6 Forwarded to gost"
	fi
else
	echo "No gost service detected. Skipping proxy forwarding."
fk

# Enable TUN device
if [ ! -c /dev/net/tun ]; then
	echo "Create TUN device..."
	mkdir -p /dev/net
	mknod /dev/net/tun c 10 200
	chmod 600 /dev/net/tun
fi

# Run OpenVPN Server
echo "Start OpenVPN..."
openvpn --daemon --config /etc/openvpn/server/server.conf
echo "OpenVPN Server is running..."
if pgrep -x "openvpn" > /dev/null; then
	if ip -6 addr | grep -q "scope global"; then
		socat TCP6-LISTEN:443,reuseaddr,fork TCP:127.0.0.1:1194
	else
		socat TCP-LISTEN:443,reuseaddr,fork TCP:127.0.0.1:1194
	fi
else
	echo "!! OpenVPN Server failed to start !!"
	exit 1
fi
