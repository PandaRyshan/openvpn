#!/bin/bash

base_conf=$(cat /root/client-configs/base.conf)
client_name="client-$(openssl rand -hex 4)"

cd /root/easy-rsa
./easyrsa --days=3650 build-client-full ${client_name} nopass

client_cert=$(cat /root/easy-rsa/pki/issued/${client_name}.crt)
client_key=$(cat /root/easy-rsa/pki/private/${client_name}.key)
ca_cert=$(cat /root/easy-rsa/pki/ca.crt)
ta_key=$(cat /root/easy-rsa/pki/ta.key)

cat > /root/client-configs/${client_name}.ovpn <<- EOF
${base_conf}

<cert>
${client_cert}
</cert>

<key>
${client_key}
</key>

<ca>
${ca_cert}
</ca>

<tls-crypt>
${ta_key}
</tls-crypt>
EOF

./easyrsa gen-crl
cp -f /root/easy-rsa/pki/crl.pem /etc/openvpn/server/
