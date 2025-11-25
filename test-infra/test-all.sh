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
echo "Будут собраны: bee2, OpenSSL с патчами для bee2evp, bee2evp, openvpn"
echo ""
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

# 1.1. Проверка версий и используемых библиотек
echo "=== 1.1. Проверка версий и используемых библиотек ==="
echo "Проверяем, какие версии bee2, OpenSSL и OpenVPN используются..."
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up"; then
    echo ""
    echo "OpenSSL:"
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server sh -c \
        "if [ -f /build/build/install/bin/openssl ]; then \
            echo '  Используется СОБРАННЫЙ OpenSSL:'; \
            /build/build/install/bin/openssl version; \
            echo '  Путь: /build/build/install/bin/openssl'; \
        else \
            echo '   Используется СИСТЕМНЫЙ OpenSSL:'; \
            openssl version; \
        fi" 2>&1
    echo ""
    echo "OpenVPN:"
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server sh -c \
        "OPENVPN_BIN=\$(find /build -name openvpn -type f -executable 2>/dev/null | head -1); \
        if [ -n \"\$OPENVPN_BIN\" ]; then \
            echo \"  Путь: \$OPENVPN_BIN\"; \
            \$OPENVPN_BIN --version | head -1; \
            echo \"  Библиотеки OpenSSL:\"; \
            ldd \"\$OPENVPN_BIN\" 2>/dev/null | grep -E '(ssl|crypto)' | sed 's/^/    /' || echo '    (не найдено)'; \
            echo \"  Поддержка engines:\"; \
            if \$OPENVPN_BIN --show-engines 2>&1 | grep -q \"OpenSSL Crypto Engines\"; then \
                echo \"    Engines доступны:\"; \
                \$OPENVPN_BIN --show-engines 2>&1 | grep -E '\[.*\]' | sed 's/^/      /'; \
            else \
                echo \"    Engines недоступны (OpenVPN собран без поддержки engines)\"; \
            fi; \
        fi" 2>&1
    echo ""
    echo "bee2evp:"
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server sh -c \
        "if [ -f /build/build/install/lib/libbee2evp.so ]; then \
            echo '   libbee2evp.so найден'; \
            ls -lh /build/build/install/lib/libbee2evp.so* | head -1 | awk '{print \"    \" \$9 \" -> \" \$10}'; \
        else \
            echo '   libbee2evp.so не найден'; \
        fi" 2>&1
else
    echo " Контейнер не запущен, пропускаем проверку"
fi
echo ""

# 1.2. Проверка bee2evp (быстрая проверка перед основными тестами)
echo "=== 1.2. Быстрая проверка bee2evp ==="
if [ -f "./scripts/script_test/check-bee2.sh" ]; then
    echo "Запуск быстрой проверки bee2evp на сервере..."
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server bash /script_test/check-bee2.sh 2>&1 | grep -E "(|||Engine bee2evp|алгоритмы bee2|СОБРАННЫЙ|СИСТЕМНЫЙ)" | head -15 || {
        echo " Предупреждение: проверка bee2evp не прошла полностью"
    }
else
    echo " Скрипт check-bee2.sh не найден, пропускаем проверку bee2evp"
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

# 4. Полная проверка bee2evp (используем скрипт check-bee2.sh)
echo "=== 4. Полная проверка bee2evp ==="
if [ -f "./scripts/script_test/check-bee2.sh" ]; then
    echo "Запуск скрипта проверки bee2evp на сервере..."
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server bash /script_test/check-bee2.sh || {
        echo " Проверка bee2evp не прошла"
        echo " Продолжаем выполнение тестов..."
    }
else
    echo " Скрипт check-bee2.sh не найден, используем базовую проверку"
    BEE2EVP_OUTPUT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl engine -c -t bee2evp 2>&1)
    if echo "$BEE2EVP_OUTPUT" | grep -q "available"; then
        echo " bee2evp engine работает"
        echo "$BEE2EVP_OUTPUT" | head -3
    else
        echo " bee2evp engine не найден или не работает"
        echo "$BEE2EVP_OUTPUT" | tail -5
    fi
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
