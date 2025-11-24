#!/bin/bash
# Простой скрипт для ping тестирования

SERVER_IP="${1:-10.8.0.1}"
COUNT="${2:-10}"

echo "=== Простой тест ping ==="
echo "Сервер: ${SERVER_IP}"
echo "Количество пакетов: ${COUNT}"
echo ""

ping -c ${COUNT} ${SERVER_IP}

if [ $? -eq 0 ]; then
    echo ""
    echo " Тест успешен!"
    exit 0
else
    echo ""
    echo " Тест не прошел"
    exit 1
fi
