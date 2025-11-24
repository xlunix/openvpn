#!/bin/bash
# Скрипт запуска OpenVPN клиента

set -e

echo "=== Запуск OpenVPN клиента ==="

# Настраиваем переменные окружения
export LD_LIBRARY_PATH=/build/build/install/lib:$LD_LIBRARY_PATH
export OPENSSL_CONF=/etc/openvpn/openssl.cnf

# Ждем запуска сервера
echo "Ожидание запуска сервера..."
sleep 5

# Проверяем наличие конфигурации
if [ ! -f /etc/openvpn/client.conf ]; then
    echo "Ошибка: файл /etc/openvpn/client.conf не найден"
    exit 1
fi

# Создаем директории для логов
mkdir -p /var/log/openvpn

# Проверяем наличие ключей
if [ ! -f /etc/openvpn/keys/client.key ] || [ ! -f /etc/openvpn/keys/client.crt ]; then
    echo "Ключи не найдены, запускаем генерацию..."
    /scripts/setup-ca.sh
fi

# Создаем TUN интерфейс
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Запускаем OpenVPN клиент
echo "Запуск OpenVPN клиента с конфигурацией /etc/openvpn/client.conf"
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
exec "$OPENVPN_BIN" --config /etc/openvpn/client.conf
