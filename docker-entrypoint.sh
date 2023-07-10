#!/bin/bash

# Wait for other container
# /wait

sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
# if you want to specific translate ip, uncomment the following line, -j MASQUERADE is dynamic way
# iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j SNAT --to-source $(hostname -I)
iptables -t nat -A POSTROUTING -s 10.8.0.0/8 -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Run OpenVPN Server
exec "$@"
