#!/bin/bash
# Скрипт для создания CA и сертификатов для OpenVPN

set -e

CA_DIR="/etc/openvpn/ca"
KEYS_DIR="/etc/openvpn/keys"
EASY_RSA_DIR="/etc/openvpn/easy-rsa"

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

# Создаем сертификат CA
if [ ! -f ca.crt ]; then
    echo "Создание сертификата CA..."
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=BY/ST=Minsk/L=Minsk/O=TestVPN/OU=IT/CN=TestVPN-CA"
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
        -subj "/C=BY/ST=Minsk/L=Minsk/O=TestVPN/OU=Server/CN=server"
fi

# Подписываем сертификат сервера
if [ ! -f ${KEYS_DIR}/server.crt ]; then
    echo "Подписание сертификата сервера..."
    openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out ${KEYS_DIR}/server.crt
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
        -subj "/C=BY/ST=Minsk/L=Minsk/O=TestVPN/OU=Client/CN=client"
fi

# Подписываем сертификат клиента
if [ ! -f ${KEYS_DIR}/client.crt ]; then
    echo "Подписание сертификата клиента..."
    openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out ${KEYS_DIR}/client.crt
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
