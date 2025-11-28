#!/bin/bash
set -e

CERT_DIR="/etc/openvpn/certs"

echo "[Client] Waiting for certs..."
sleep 3

if [ ! -f "$CERT_DIR/client.key" ]; then
    echo "[Client] ERROR: client certificates not found!"
    ls -l "$CERT_DIR"
    exit 1
fi

echo "[Client] Launching OpenVPN ..."
exec openvpn --config /etc/openvpn/client.conf