#!/bin/bash
# Скрипт для тестирования ping/pong через OpenVPN

set -e

echo "=== Тест ping/pong через OpenVPN ==="

# Ждем запуска VPN
echo "Ожидание запуска VPN соединения..."
sleep 10

# Проверяем доступность сервера
SERVER_IP="10.8.0.1"
CLIENT_IP="10.8.0.2"

echo "Проверка доступности сервера VPN (${SERVER_IP})..."

# Пинг сервера
if ping -c 3 ${SERVER_IP} > /dev/null 2>&1; then
    echo " Сервер доступен!"
else
    echo " Сервер недоступен"
    exit 1
fi

# Тест ping с подробным выводом
echo ""
echo "=== Детальный тест ping ==="
ping -c 5 ${SERVER_IP}

# Тест обратного ping (если есть доступ к клиенту)
echo ""
echo "=== Тест обратного ping ==="
if ping -c 3 ${CLIENT_IP} > /dev/null 2>&1; then
    echo " Клиент доступен с сервера!"
    ping -c 3 ${CLIENT_IP}
else
    echo " Клиент недоступен (это нормально, если клиент не настроен на ответ)"
fi

# Проверка маршрутизации
echo ""
echo "=== Проверка маршрутизации ==="
ip route | grep "10.8.0.0" || echo "Маршрут VPN не найден"

# Тест TCP соединения (если есть сервис на сервере)
echo ""
echo "=== Тест TCP соединения ==="
if timeout 2 bash -c "echo > /dev/tcp/${SERVER_IP}/1194" 2>/dev/null; then
    echo " TCP порт 1194 доступен"
else
    echo " TCP порт 1194 недоступен (это нормально)"
fi

echo ""
echo "=== Тест завершен ==="
