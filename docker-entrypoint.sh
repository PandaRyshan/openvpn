#!/bin/bash

# Wait for other container
# /wait

################################
# WORKDIR /root/easy-rsa
################################

if [ ! -f vars ]; then
	echo "vars not found, copying..."
	cp /root/easy-rsa/vars.example /root/easy-rsa/vars
fi

# Init PKI
if [ ! -d "/root/easy-rsa/pki" ]; then
	echo "default pki not found, init pki"
	echo yes | ./easyrsa init-pki
fi

# Build CA
if [ ! -f "/root/easy-rsa/pki/ca.crt" ]; then
	echo "default ca.crt not found, creating..."
	if [ -z "$DEFAULT_CA_PASSPHRASE" ]; then
		echo "DEFAULT_PASSPHRASE not found, creating..."
		DEFAULT_CA_PASSPHRASE=$(openssl rand -base64 14)
		echo -e "$DEFAULT_CA_PASSPHRASE" > /root/easy-rsa/pki/DEFAULT_CA_PASSPHRASE
	fi
	/usr/bin/expect << EOF
spawn ./easyrsa build-ca
expect "Enter New CA Key Passphrase"
send "$DEFAULT_CA_PASSPHRASE\r"
expect "Confirm New CA Key Passphrase"
send "$DEFAULT_CA_PASSPHRASE\r"
expect "Common Name (eg: your user, host, or server name)"
send "\r"
expect eof
EOF
	# echo -e "$DEFAULT_CA_PASSPHRASE\n$DEFAULT_CA_PASSPHRASE\n" | ./easyrsa build-ca
	if [ ! -f "/etc/openvpn/server/ca.crt" ]; then
		cp pki/ca.crt /etc/openvpn/server/
	fi
fi

# Build Server crt
if [ ! -f "/root/easy-rsa/pki/issued/server.crt" ]; then
	echo "default server.crt not found, creating..."
	/usr/bin/expect << EOF
spawn ./easyrsa --days=3650 build-server-full server nopass
expect "Confirm request details"
send "yes\r"
expect "Enter pass phrase for"
send "$DEFAULT_CA_PASSPHRASE\r"
expect eof
EOF
	if [ ! -f "/etc/openvpn/server/server.crt" ]; then
		cp pki/issued/server.crt /etc/openvpn/server/
		cp pki/private/server.key /etc/openvpn/server/
	fi
fi

# Build tls auth/crypt key
if [ ! -f "/root/easy-rsa/pki/ta.key" ]; then
	echo "default ta.key not found, creating..."
	openvpn --genkey secret /root/easy-rsa/pki/ta.key
	if [ ! -f "/etc/openvpn/server/ta.key" ]; then
		cp /root/easy-rsa/pki/ta.key /etc/openvpn/server/
	fi
fi

# Build DH
if [ ! -f "/root/easy-rsa/pki/dh.pem" ]; then
	echo "default dh.pem not found, createing..."
	./easyrsa gen-dh
	if [ ! -f "/etc/openvpn/server/dh.pem" ]; then
		cp /root/easy-rsa/pki/dh.pem /etc/openvpn/server/
	fi
fi

# Build CRL
if [ ! -f "/root/easy-rsa/pki/crl.pem" ]; then
	echo "default crl.pem not found, creating..."
	/usr/bin/expect << EOF
spawn ./easyrsa gen-crl
expect "Enter pass phrase for"
send "$DEFAULT_CA_PASSPHRASE\r"
expect eof
EOF
	if [ ! -f "/etc/openvpn/server/crl.pem" ]; then
		cp /root/easy-rsa/pki/crl.pem /etc/openvpn/server/
	fi
fi

PROTO=${PROTO:-"tcp"}
if [ "$PROTO" == "tcp" ]; then
	PROTO_SERVER="tcp-server"
	PROTO_CLIENT="tcp-client"
else
	PROTO_SERVER="udp"
	PROTO_CLIENT="udp"
fi

# Build server config
# if you want a tcp server, set: proto tcp-server
if [ ! -f "/etc/openvpn/server/server.conf" ]; then
	echo "server.conf not found, creating..."
	touch /etc/openvpn/server/server.conf
	cat > /etc/openvpn/server/server.conf <<- EOF
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
	server 172.20.0.0 255.255.255.0
	server-ipv6 2001:db8:2::/64
	# ifconfig-pool <start-ip> <end-ip>
	# ifconfig-ipv6-pool <start-ip> <end-ip>
	push "redirect-gateway def1 bypass-dhcp"
	push "dhcp-option DNS 1.1.1.1"
	push "dhcp-option DNS 8.8.8.8"
	keepalive 10 120
	cipher AES-256-GCM
	user nobody
	group nogroup
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

mkdir -p /root/client-configs
if [ ! -f "/root/client-configs/base.conf" ]; then
	echo "base.conf not found, creating..."
	touch /root/client-configs/base.conf
	cat > /root/client-configs/base.conf <<- EOF
	client
	dev tun
	proto ${PROTO_CLIENT}
	remote ${DOMAIN_OR_IP} ${PORT}
	resolv-retry infinite
	nobind
	user nobody
	group nogroup
	persist-key
	persist-tun
	remote-cert-tls server
	cipher AES-256-GCM
	tls-version-min 1.3
	auth SHA256
	key-direction 1
	verb 3
	EOF
	/build-client.sh	
fi

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -s 172.20.0.0/24 -o eth0 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s 2001:db8:2::/64 -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpenVPN Server

if [ "$PROTO" == "tcp" ]; then
	openvpn /etc/openvpn/server/server.conf &
	socat TCP-LISTEN:443,reuseaddr,fork TCP:127.0.0.1:1194
else
	openvpn /etc/openvpn/server/server.conf
fi
