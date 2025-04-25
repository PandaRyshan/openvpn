#!/bin/bash

client_name="$1"
ca_key=$(cat /etc/openvpn/certs/pki/DEFAULT_CA_PASSPHRASE)

if [ -z "$client_name" ]; then
    echo "Error: A client name must be provided."
    exit 0
fi

cd /etc/openvpn/certs
/usr/bin/expect << EOF
spawn /usr/share/easy-rsa/easyrsa revoke ${client_name}
expect "Continue with revocation"
send "yes\r"
expect "Enter pass phrase for"
send "$ca_key\r"
expect eof
EOF

rm /etc/openvpn/clients/${client_name}.ovpn
