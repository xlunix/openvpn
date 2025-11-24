#!/bin/bash
# Простой pong сервер для тестирования

PORT="${1:-9999}"

echo "=== Запуск pong сервера на порту ${PORT} ==="

# Создаем простой TCP сервер, который отвечает "pong" на любой запрос
while true; do
    echo -e "pong\n" | nc -l ${PORT} -q 1 2>/dev/null
    if [ $? -ne 0 ]; then
        sleep 1
        continue
    fi
done
