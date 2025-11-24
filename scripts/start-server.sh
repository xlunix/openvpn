#!/bin/bash
# Скрипт запуска OpenVPN сервера

set -e

echo "=== Запуск OpenVPN сервера ==="

# Настраиваем переменные окружения
export LD_LIBRARY_PATH=/build/build/install/lib:$LD_LIBRARY_PATH
export OPENSSL_CONF=/etc/openvpn/openssl.cnf

# Проверяем наличие конфигурации
if [ ! -f /etc/openvpn/server.conf ]; then
    echo "Ошибка: файл /etc/openvpn/server.conf не найден"
    exit 1
fi

# Создаем директории для логов
mkdir -p /var/log/openvpn

# Проверяем наличие ключей
if [ ! -f /etc/openvpn/keys/server.key ] || [ ! -f /etc/openvpn/keys/server.crt ]; then
    echo "Ключи не найдены, запускаем генерацию..."
    /scripts/setup-ca.sh
    sleep 10  # Даем время на генерацию DH параметров
fi

# Создаем TUN интерфейс
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Создаем симлинк для bee2evp engine (чтобы OpenSSL мог его найти)
if [ -f /build/build/install/lib/libbee2evp.so ]; then
    mkdir -p /usr/lib/x86_64-linux-gnu/engines-3
    if [ ! -f /usr/lib/x86_64-linux-gnu/engines-3/bee2evp.so ]; then
        ln -sf /build/build/install/lib/libbee2evp.so /usr/lib/x86_64-linux-gnu/engines-3/bee2evp.so
    fi
fi

# Запускаем OpenVPN сервер
echo "Запуск OpenVPN сервера с конфигурацией /etc/openvpn/server.conf"
# Ищем openvpn в разных местах
OPENVPN_BIN="/build/build/install/bin/openvpn"
if [ ! -f "$OPENVPN_BIN" ]; then
    OPENVPN_BIN="/build/build/openvpn/openvpn"
fi
if [ ! -f "$OPENVPN_BIN" ]; then
    echo "Ошибка: OpenVPN не найден!"
    find /build -name openvpn -type f 2>/dev/null | head -5
    exit 1
fi
exec "$OPENVPN_BIN" --config /etc/openvpn/server.conf
