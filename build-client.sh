#!/bin/bash

client_name="$1"
base_conf=$(cat /root/client-configs/base.conf)
ca_key=$(cat /root/easy-rsa/pki/DEFAULT_CA_PASSPHRASE)

if [ -z "$client_name" ]; then
	client_name="client-$(openssl rand -hex 4)"
else
	client_name="client-$client_name"
fi

cd /root/easy-rsa
/usr/bin/expect << EOF
spawn ./easyrsa --days=3650 build-client-full ${client_name} nopass
expect "Confirm request details"
send "yes\r"
expect "Enter pass phrase for"
send "$ca_key\r"
expect eof
EOF

client_inline=$(cat /root/easy-rsa/pki/inline/${client_name}.inline)
ta_key=$(cat /root/easy-rsa/pki/ta.key)

cat > /root/client-configs/${client_name}.ovpn <<- EOF
${base_conf}

${client_inline}

<tls-crypt>
${ta_key}
</tls-crypt>
EOF
