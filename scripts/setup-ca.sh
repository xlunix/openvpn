#!/bin/bash
# Скрипт для создания CA и сертификатов для OpenVPN

set -e

CA_DIR="/etc/openvpn/ca"
KEYS_DIR="/etc/openvpn/keys"
EASY_RSA_DIR="/etc/openvpn/easy-rsa"

# Настройки для сертификатов (можно переопределить через переменные окружения)
CERT_COUNTRY="${CERT_COUNTRY:-BY}"
CERT_STATE="${CERT_STATE:-Minsk}"
CERT_CITY="${CERT_CITY:-Minsk}"
CERT_ORG="${CERT_ORG:-TestVPN}"
CERT_OU_CA="${CERT_OU_CA:-IT}"
CERT_OU_SERVER="${CERT_OU_SERVER:-Server}"
CERT_OU_CLIENT="${CERT_OU_CLIENT:-Client}"
CERT_CN_CA="${CERT_CN_CA:-TestVPN-CA}"
CERT_CN_SERVER="${CERT_CN_SERVER:-server}"
CERT_CN_CLIENT="${CERT_CN_CLIENT:-client}"

echo "=== Настройка CA и генерация ключей ==="

# Создаем директории
mkdir -p ${CA_DIR} ${KEYS_DIR} ${EASY_RSA_DIR} /var/log/openvpn

# Используем openssl для создания CA
cd ${CA_DIR}

# Создаем приватный ключ CA
if [ ! -f ca.key ]; then
    echo "Создание приватного ключа CA..."
    openssl genrsa -out ca.key 2048
    chmod 600 ca.key
fi

# Создаем сертификат CA с правильными расширениями
if [ ! -f ca.crt ]; then
    echo "Создание сертификата CA..."
    # Создаем временный конфиг для расширений CA
    cat > /tmp/ca_ext.conf <<EOF
[ v3_ca ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
    # Создаем запрос на сертификат
    openssl req -new -key ca.key -out ca.csr \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU_CA}/CN=${CERT_CN_CA}"
    # Подписываем как самоподписанный сертификат с расширениями
    openssl x509 -req -days 3650 -in ca.csr -signkey ca.key -out ca.crt \
        -extensions v3_ca -extfile /tmp/ca_ext.conf
    rm -f /tmp/ca_ext.conf ca.csr
fi

# Создаем ключ для сервера
if [ ! -f ${KEYS_DIR}/server.key ]; then
    echo "Создание ключа сервера..."
    openssl genrsa -out ${KEYS_DIR}/server.key 2048
    chmod 600 ${KEYS_DIR}/server.key
fi

# Создаем запрос на сертификат для сервера
if [ ! -f server.csr ]; then
    echo "Создание запроса на сертификат сервера..."
    openssl req -new -key ${KEYS_DIR}/server.key -out server.csr \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU_SERVER}/CN=${CERT_CN_SERVER}"
fi

# Подписываем сертификат сервера с правильными расширениями
if [ ! -f ${KEYS_DIR}/server.crt ]; then
    echo "Подписание сертификата сервера..."
    # Создаем временный конфиг для расширений сертификата сервера
    cat > /tmp/server_ext.conf <<EOF
[ v3_server ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
    openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out ${KEYS_DIR}/server.crt \
        -extensions v3_server -extfile /tmp/server_ext.conf
    rm -f /tmp/server_ext.conf
fi

# Создаем ключ для клиента
if [ ! -f ${KEYS_DIR}/client.key ]; then
    echo "Создание ключа клиента..."
    openssl genrsa -out ${KEYS_DIR}/client.key 2048
    chmod 600 ${KEYS_DIR}/client.key
fi

# Создаем запрос на сертификат для клиента
if [ ! -f client.csr ]; then
    echo "Создание запроса на сертификат клиента..."
    openssl req -new -key ${KEYS_DIR}/client.key -out client.csr \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU_CLIENT}/CN=${CERT_CN_CLIENT}"
fi

# Подписываем сертификат клиента с правильными расширениями
if [ ! -f ${KEYS_DIR}/client.crt ]; then
    echo "Подписание сертификата клиента..."
    # Создаем временный конфиг для расширений сертификата клиента
    cat > /tmp/client_ext.conf <<EOF
[ v3_client ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
    openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out ${KEYS_DIR}/client.crt \
        -extensions v3_client -extfile /tmp/client_ext.conf
    rm -f /tmp/client_ext.conf
fi

# Создаем ключ для TLS
if [ ! -f ${KEYS_DIR}/ta.key ]; then
    echo "Создание TLS ключа..."
    OPENVPN_BIN="/build/build/install/bin/openvpn"
    if [ ! -f "$OPENVPN_BIN" ]; then
        OPENVPN_BIN="/build/build/openvpn/openvpn"
    fi
    if [ -f "$OPENVPN_BIN" ]; then
        $OPENVPN_BIN --genkey --secret ${KEYS_DIR}/ta.key
    else
        echo "Предупреждение: OpenVPN не найден, пропускаем генерацию ta.key"
    fi
fi

# Создаем Diffie-Hellman параметры (минимум 2048 бит для OpenSSL 3.0)
if [ ! -f ${KEYS_DIR}/dh.pem ]; then
    echo "Создание DH параметров 2048 бит (это может занять время)..."
    openssl dhparam -out ${KEYS_DIR}/dh.pem 2048
fi

echo "=== Ключи и сертификаты созданы ==="
echo "CA сертификат: ${CA_DIR}/ca.crt"
echo "Серверные ключи: ${KEYS_DIR}/server.*"
echo "Клиентские ключи: ${KEYS_DIR}/client.*"
echo "TLS ключ: ${KEYS_DIR}/ta.key"
echo "DH параметры: ${KEYS_DIR}/dh.pem"
