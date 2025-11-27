#!/bin/bash
set -e

CERT_DIR="/etc/openvpn/certs"
mkdir -p $CERT_DIR

if [ ! -f "$CERT_DIR/ca.crt" ]; then
    echo "[Server] Generating certificates..."

    # CA
    openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out $CERT_DIR/ca.key
    openssl req -x509 -new -engine bee2evp -key $CERT_DIR/ca.key -out $CERT_DIR/ca.crt \
        -days 3650 -subj "/CN=MyCA" -sha256

    # Server
    openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out $CERT_DIR/server.key
    openssl req -new -engine bee2evp -key $CERT_DIR/server.key -out $CERT_DIR/server.csr -subj "/CN=Server"
    openssl x509 -req -engine bee2evp -in $CERT_DIR/server.csr \
        -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial \
        -days 365 -out $CERT_DIR/server.crt -sha256

    # Client
    openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out $CERT_DIR/client.key
    openssl req -new -engine bee2evp -key $CERT_DIR/client.key -out $CERT_DIR/client.csr -subj "/CN=Client"
    openssl x509 -req -engine bee2evp -in $CERT_DIR/client.csr \
        -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial \
        -days 365 -out $CERT_DIR/client.crt -sha256
fi

echo "[Server] Launching OpenVPN..."
exec openvpn --config /etc/openvpn/server.conf
