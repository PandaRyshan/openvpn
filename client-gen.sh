#!/bin/bash

client_name="$1"
base_conf=$(cat /etc/openvpn/clients/base.conf)
ca_key=$(cat /etc/openvpn/certs/pki/DEFAULT_CA_PASSPHRASE)

if [ -z "$client_name" ]; then
	client_name="$(openssl rand -hex 4)"
else
	client_name="$client_name"
fi

cd /etc/openvpn/certs
/usr/bin/expect << EOF
spawn /usr/share/easy-rsa/easyrsa --days=3650 build-client-full ${client_name} nopass
expect "Confirm requested details:"
send "yes\r"
expect "Enter pass phrase for"
send "$ca_key\r"
expect eof
EOF

client_inline=$(cat /etc/openvpn/certs/pki/inline/private/${client_name}.inline)
ta_key=$(cat /etc/openvpn/certs/pki/ta.key)

cat > /etc/openvpn/clients/${client_name}.ovpn <<- EOF
${base_conf}

${client_inline}

<tls-crypt>
${ta_key}
</tls-crypt>
EOF
