#!/bin/bash
# Скрипт для автоматического запуска всех тестов
# Используется в CI/CD для проверки работоспособности после слияния изменений

set -e

echo "=========================================="
echo "Автоматический запуск тестов OpenVPN"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция для вывода ошибки и выхода
error_exit() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    error_exit "Docker не установлен"
fi

# Определение команды compose
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

COMPOSE_FILE="docker-compose-test.yml"

# Переход в директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# test-infra находится на 2 уровня выше (script_test -> scripts -> test-infra)
TEST_INFRA_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$TEST_INFRA_DIR"

echo "Рабочая директория: $TEST_INFRA_DIR"
echo ""

# 1. Остановка предыдущих контейнеров (если есть)
echo "=== Очистка предыдущих запусков ==="
$COMPOSE_CMD -f $COMPOSE_FILE down -v 2>/dev/null || true
echo ""

# 2. Сборка образов
echo "=== Сборка Docker образов ==="
$COMPOSE_CMD -f $COMPOSE_FILE build || error_exit "Ошибка сборки образов"
echo ""

# 3. Запуск сервисов
echo "=== Запуск сервисов ==="
$COMPOSE_CMD -f $COMPOSE_FILE up -d || error_exit "Ошибка запуска сервисов"
echo ""

# 4. Ожидание готовности сервисов
echo "=== Ожидание готовности сервисов ==="
echo "Ожидание 30 секунд для инициализации VPN..."
sleep 30

# Проверка статуса сервисов
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if $COMPOSE_CMD -f $COMPOSE_FILE ps | grep -q "Up.*openvpn-server" && \
       $COMPOSE_CMD -f $COMPOSE_FILE ps | grep -q "Up.*openvpn-client"; then
        echo "Сервисы запущены"
        break
    fi
    echo "Ожидание... ($WAITED/$MAX_WAIT сек)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo -e "${RED}Таймаут ожидания запуска сервисов${NC}"
    $COMPOSE_CMD -f $COMPOSE_FILE logs
    error_exit "Сервисы не запустились вовремя"
fi
echo ""

# 5. Запуск тестов
echo "=== Запуск тестов ==="
if [ -f "$TEST_INFRA_DIR/test-all.sh" ]; then
    bash "$TEST_INFRA_DIR/test-all.sh" || error_exit "Тесты не прошли"
else
    echo -e "${YELLOW}⚠ test-all.sh не найден, запускаем базовые тесты${NC}"
    
    # Базовые тесты
    echo "Проверка ping от клиента к серверу..."
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-client ping -c 5 10.8.0.1 || \
        error_exit "Ping от клиента к серверу не прошел"
    
    echo "Проверка ping от сервера к клиенту..."
    $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server ping -c 5 10.8.0.2 || \
        error_exit "Ping от сервера к клиенту не прошел"
fi
echo ""

# 6. Итоговый отчет
echo "=========================================="
echo -e "${GREEN} Все тесты пройдены успешно!${NC}"
echo "=========================================="
echo ""

# Опционально: остановка сервисов (раскомментируйте, если нужно)
# echo "Остановка сервисов..."
# $COMPOSE_CMD -f $COMPOSE_FILE down

exit 0

