#!/bin/bash
# Главный скрипт для запуска всех тестов OpenVPN
# Используется в тестовой ветке для автоматической проверки

set -e

echo "=========================================="
echo " Запуск полного набора тестов OpenVPN"
echo "=========================================="
echo ""

# Проверка, что docker compose доступен
if ! command -v docker &> /dev/null; then
    echo "Ошибка: Docker не установлен"
    exit 1
fi

# Используем docker-compose или docker compose в зависимости от версии
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Проверка, что используется правильный compose файл
COMPOSE_FILE="docker-compose-test.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Ошибка: файл $COMPOSE_FILE не найден"
    exit 1
fi

# Остановка и удаление существующих контейнеров
echo "=== Остановка существующих контейнеров ==="
if $COMPOSE_CMD -f $COMPOSE_FILE ps | grep -q "Up"; then
    echo "Останавливаем и удаляем существующие контейнеры..."
    $COMPOSE_CMD -f $COMPOSE_FILE down
    echo "Контейнеры остановлены"
else
    echo "Контейнеры не запущены"
fi
echo ""

# Пересборка образов
echo "=== Пересборка Docker образов ==="
echo "Это может занять некоторое время..."
$COMPOSE_CMD -f $COMPOSE_FILE build --no-cache || {
    echo " Ошибка при сборке образов"
    exit 1
}
echo " Образы успешно пересобраны"
echo ""

# Запуск контейнеров
echo "=== Запуск контейнеров ==="
$COMPOSE_CMD -f $COMPOSE_FILE up -d || {
    echo " Ошибка при запуске контейнеров"
    exit 1
}
echo "Ожидание инициализации сервисов (30 секунд)..."
sleep 30
echo " Контейнеры запущены"
echo ""

# 1. Проверка статуса системы
echo "=== 1. Проверка статуса ==="
if [ -f "./scripts/script_test/check-status.sh" ]; then
    bash ./scripts/script_test/check-status.sh
else
    echo " Скрипт check-status.sh не найден, пропускаем проверку статуса"
fi

echo ""

# 2. Запуск тестов ping через VPN (выполняем внутри клиентского контейнера)
echo "=== 2. Запуск тестов ping ==="
$COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-client bash /script_test/test-ping.sh || {
    echo " Тесты ping не прошли"
    exit 1
}

echo ""

# 3. Проверка ping от клиента к серверу
echo "=== 3. Проверка ping (клиент -> сервер) ==="
$COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-client ping -c 5 10.8.0.1 || {
    echo " Ping от клиента к серверу не прошел"
    exit 1
}

echo ""

# 4. Проверка bee2evp engine
echo "=== 4. Проверка bee2evp ==="
BEE2EVP_OUTPUT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl engine -c -t bee2evp 2>&1)
if echo "$BEE2EVP_OUTPUT" | grep -q "available"; then
    echo " bee2evp engine работает"
    echo "$BEE2EVP_OUTPUT" | head -3
else
    echo " bee2evp engine не найден или не работает"
    echo "$BEE2EVP_OUTPUT" | tail -5
fi

echo ""

# 5. Дополнительные тесты (если есть)
if [ -f "./scripts/script_test/ping-pong-test.sh" ]; then
    echo "=== 5. Тест ping-pong ==="
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-client bash /script_test/ping-pong-test.sh || {
        echo " Тест ping-pong не прошел (возможно, pong сервер не запущен)"
    }
    echo ""
fi

echo "=========================================="
echo " Все основные проверки завершены!"
echo "=========================================="
echo ""
echo "Для просмотра логов:"
echo "  $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo ""
echo "Для остановки сервисов:"
echo "  $COMPOSE_CMD -f $COMPOSE_FILE down"
echo ""
