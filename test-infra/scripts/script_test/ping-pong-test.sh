#!/bin/bash
# Скрипт для тестирования ping-pong через OpenVPN

set -e

SERVER_IP="${1:-10.8.0.1}"
PONG_PORT="${2:-9999}"

echo "=== Тест ping-pong через OpenVPN ==="
echo "Сервер: ${SERVER_IP}"
echo "Pong порт: ${PONG_PORT}"
echo ""

# Ждем запуска VPN
echo "Ожидание запуска VPN..."
sleep 5

# Тест 1: Ping
echo "=== Тест 1: Ping ==="
if ping -c 5 ${SERVER_IP} > /dev/null 2>&1; then
    echo " Ping успешен!"
    ping -c 3 ${SERVER_IP}
else
    echo " Ping не прошел"
    exit 1
fi

echo ""

# Тест 2: Pong (TCP)
echo "=== Тест 2: Pong (TCP) ==="
echo "Отправка 'ping' на ${SERVER_IP}:${PONG_PORT}..."

# Используем timeout для ограничения времени ожидания
RESPONSE=$(timeout 3 bash -c "echo 'ping' | nc ${SERVER_IP} ${PONG_PORT}" 2>/dev/null || echo "")

if [ -n "${RESPONSE}" ] && echo "${RESPONSE}" | grep -q "pong"; then
    echo " Получен ответ: ${RESPONSE}"
    echo " Pong тест успешен!"
else
    echo " Pong сервер не отвечает (возможно, не запущен)"
    echo "Запустите pong сервер: /scripts/pong-server.sh ${PONG_PORT}"
fi

echo ""
echo "=== Тест завершен ==="
