#!/bin/bash

# Wait for other container
# /wait

################################
# WORKDIR /root/easy-rsa
################################

# Init PKI
if [ ! -d "/root/easy-rsa/pki" ]; then
	echo "default pki not found, init pki"
	./easyrsa init-pki
fi

# Build CA
if [ ! -f "/root/easy-rsa/pki/ca.crt" ]; then
	echo "default ca.crt not found, creating..."
	if [ -z "$DEFAULT_CA_PASSPHRASE" ]; then
		echo "DEFAULT_PASSPHRASE not found, creating..."
		DEFAULT_CA_PASSPHRASE=$(openssl rand -base64 14)
	fi
	echo -e "$DEFAULT_CA_PASSPHRASE\n$DEFAULT_CA_PASSPHRASE\n\n" | ./easyrsa build-ca nopass
	echo "DEFAULT_PASSPHRASE=$DEFAULT_CA_PASSPHRASE" > /root/easy-rsa/pki/DEFAULT_PASSPHRASE
	if [ ! -f "/etc/openvpn/server/ca.crt" ]; then
		cp pki/ca.crt /etc/openvpn/server/
	fi
fi

# Build Server crt
if [ ! -f "/root/easy-rsa/pki/issued/server.crt" ]; then
	echo "default server.crt not found, creating..."
    ./easyrsa --days=3650 build-server-full server nopass
	if [ ! -f "/etc/openvpn/server/server.crt" ]; then
		cp pki/issued/server.crt /etc/openvpn/server/
		cp pki/private/server.key /etc/openvpn/server/
	fi
fi

# Build Client crt
# if [ ! -f "/root/easy-rsa/pki/issued/client.crt" ]; then
# 	echo "default client.crt not found, creating..."
# 	./easyrsa --days=3650 build-client-full client nopass
# fi

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
	./easyrsa gen-crl
	if [ ! -f "/etc/openvpn/server/crl.pem" ]; then
		cp /root/easy-rsa/pki/crl.pem /etc/openvpn/server/
	fi
fi

# Build server config
if [ ! -f "/etc/openvpn/server/server.conf" ]; then
	echo "server.conf not found, creating..."
    touch /etc/openvpn/server/server.conf
	cat > /etc/openvpn/server/server.conf <<- EOF
	verify-client-cert
	key-direction 0
	duplicate-cn
	port 1194
	proto tcp
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
	server 10.8.0.0 255.255.255.0
	push "redirect-gateway def1 bypass-dhcp"
	ifconfig-pool-persist ipp.txt
	push "dhcp-option DNS 1.1.1.1"
	push "dhcp-option DNS 8.8.8.8"
	keepalive 10 120
	cipher AES-256-GCM
	user nobody
	group nogroup
	persist-key
	persist-tun
	verb 3
	explicit-exit-notify
	EOF
fi

# Build client base config
HOSTIP=$(curl -s https://ipinfo.io/ip)
mkdir -p /root/client-configs
if [ ! -f "/root/client-configs/base.conf" ]; then
	echo "base.conf not found, creating..."
	touch /root/client-configs/base.conf
	cat > /root/client-configs/base.conf <<- EOF
	client
	dev tun
	proto tcp
	remote ${HOSTIP} 1194
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
	explicit-exit-notify
	EOF
	/root/easy-rsa/build-client.sh	
fi

sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
# if you want to specific translate ip, uncomment the following line, -j MASQUERADE is dynamic way
# iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j SNAT --to-source $(hostname -I)
iptables -t nat -A POSTROUTING -s 10.8.0.0/8 -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpenVPN Server
exec "$@"
