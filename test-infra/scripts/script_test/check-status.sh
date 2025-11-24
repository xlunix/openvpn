#!/bin/bash
# Скрипт для проверки работоспособности всей системы

set -e

echo "=========================================="
echo "Проверка работоспособности OpenVPN + bee2evp"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${NC} $1"
        return 0
    else
        echo -e "${RED}${NC} $1"
        return 1
    fi
}

# 1. Проверка контейнеров
echo "1. Проверка контейнеров..."
echo "---------------------------"
# Определяем команду docker compose
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Определяем путь к docker-compose файлу (ожидается запуск из test-infra/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_INFRA_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="docker-compose-test.yml"

# Переходим в test-infra для работы с docker compose
cd "$TEST_INFRA_DIR"

CONTAINERS=$($COMPOSE_CMD -f $COMPOSE_FILE ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null || $COMPOSE_CMD -f $COMPOSE_FILE ps --format "{{.Name}}" 2>/dev/null)
if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}${NC} Контейнеры не запущены"
    echo "   Запустите: cd test-infra && docker compose -f docker-compose-test.yml up -d"
    echo "   Или используйте ./test-all.sh для автоматического запуска"
    echo ""
    # Продолжаем проверку, даже если контейнеры не запущены
fi

# Проверяем контейнеры по именам сервисов
for service in openvpn-server openvpn-client; do
    CONTAINER_NAME="${service}-test"
    if echo "$CONTAINERS" | grep -q "$CONTAINER_NAME"; then
        STATUS=$($COMPOSE_CMD -f $COMPOSE_FILE ps --format "{{.Status}}" "$service" 2>/dev/null | head -1 || echo "")
        if [ -n "$STATUS" ] && echo "$STATUS" | grep -q "Up"; then
            echo -e "${GREEN}${NC} $CONTAINER_NAME: $STATUS"
        elif [ -n "$STATUS" ]; then
            echo -e "${RED}${NC} $CONTAINER_NAME: $STATUS"
        else
            # Если не получили статус через сервис, пробуем через контейнер
            STATUS=$(docker ps --format "{{.Status}}" --filter "name=$CONTAINER_NAME" 2>/dev/null | head -1 || echo "")
            if [ -n "$STATUS" ] && echo "$STATUS" | grep -q "Up"; then
                echo -e "${GREEN}${NC} $CONTAINER_NAME: $STATUS"
            else
                echo -e "${YELLOW}${NC} $CONTAINER_NAME: статус неизвестен"
            fi
        fi
    else
        echo -e "${YELLOW}${NC} $CONTAINER_NAME: не найден в списке контейнеров"
    fi
done
echo ""

# 2. Проверка сети
echo "2. Проверка сети..."
echo "-------------------"
NETWORK=$(docker network ls | grep test-infra_vpn-network || docker network ls | grep vpn-network)
if [ -n "$NETWORK" ]; then
    echo -e "${GREEN}${NC} Сеть vpn-network создана"
else
    echo -e "${RED}${NC} Сеть vpn-network не найдена"
fi
echo ""

# 3. Проверка OpenVPN в образе
echo "3. Проверка OpenVPN в образе..."
echo "-------------------------------"
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up"; then
    OPENVPN_PATH=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server find /build -name openvpn -type f 2>/dev/null | head -1)
    if [ -n "$OPENVPN_PATH" ]; then
        echo -e "${GREEN}${NC} OpenVPN найден: $OPENVPN_PATH"
        VERSION=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server "$OPENVPN_PATH" --version 2>/dev/null | head -1)
        if [ -n "$VERSION" ]; then
            echo "   Версия: $VERSION"
        fi
    else
        echo -e "${YELLOW}${NC} OpenVPN не найден в запущенном контейнере"
    fi
else
    # Если контейнер не запущен, проверяем образ напрямую
    IMAGE_NAME=$($COMPOSE_CMD -f $COMPOSE_FILE config 2>/dev/null | grep -A 5 "openvpn-server:" | grep "image:" | awk '{print $2}' 2>/dev/null || echo "")
    if [ -z "$IMAGE_NAME" ]; then
        # Если image не указан, используем имя из build
        IMAGE_NAME="test-infra-openvpn-server"
    fi
    OPENVPN_PATH=$(docker run --rm "$IMAGE_NAME" find /build -name openvpn -type f 2>/dev/null | head -1)
    if [ -n "$OPENVPN_PATH" ]; then
        echo -e "${GREEN}${NC} OpenVPN найден в образе: $OPENVPN_PATH"
    else
        echo -e "${YELLOW}${NC} OpenVPN не найден в образе (контейнер не запущен для проверки)"
    fi
fi
echo ""

# 4. Проверка bee2 и bee2evp библиотек
echo "4. Проверка bee2 и bee2evp..."
echo "-----------------------------"
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up"; then
    # Проверка наличия библиотек (ищем во всем /build, не только в install/lib)
    BEE2_LIB=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server find /build -name "libbee2.so*" -type f 2>/dev/null | head -1)
    BEE2EVP_LIB=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server find /build/build/install/lib -name "libbee2evp.so*" -type f 2>/dev/null | head -1)
    
    # Проверяем динамическую библиотеку
    if [ -n "$BEE2_LIB" ]; then
        echo -e "${GREEN}${NC} libbee2.so найден: $(basename $BEE2_LIB)"
    else
        # Проверяем статическую библиотеку
        BEE2_STATIC_LIB=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server find /build/build/install/lib -name "libbee2*.a" -type f 2>/dev/null | head -1)
        if [ -n "$BEE2_STATIC_LIB" ]; then
            echo -e "${GREEN}${NC} libbee2 найден (статическая библиотека): $(basename $BEE2_STATIC_LIB)"
        else
            echo -e "${YELLOW}${NC} libbee2.so не найден (возможно статически слинкован в bee2evp)"
        fi
    fi
    
    if [ -n "$BEE2EVP_LIB" ]; then
        echo -e "${GREEN}${NC} libbee2evp.so найден: $(basename $BEE2EVP_LIB)"
        
        # Проверка зависимостей bee2evp от bee2
        LDD_OUTPUT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server ldd "$BEE2EVP_LIB" 2>/dev/null)
        if echo "$LDD_OUTPUT" | grep -q "libbee2"; then
            BEE2_DEP=$(echo "$LDD_OUTPUT" | grep "libbee2" | head -1)
            if echo "$BEE2_DEP" | grep -q "not found"; then
                echo -e "${RED}${NC} libbee2evp не может найти libbee2 (не прилинкован)"
            else
                BEE2_PATH=$(echo "$BEE2_DEP" | awk '{print $3}')
                echo -e "${GREEN}${NC} libbee2evp динамически прилинкован к libbee2: $BEE2_PATH"
            fi
        else
            # Если libbee2 не найден в ldd, возможно он статически слинкован
            # Проверяем наличие исходников или статических библиотек bee2
            BEE2_STATIC=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server find /build -type d -name "bee2" 2>/dev/null | head -1)
            if [ -n "$BEE2_STATIC" ]; then
                echo -e "${GREEN}${NC} libbee2evp использует bee2 (bee2 статически слинкован или встроен)"
            else
                echo -e "${YELLOW}${NC} libbee2 не найден как отдельная библиотека (возможно статически слинкован)"
            fi
        fi
        
        # Проверка загрузки bee2evp через OpenSSL engine
        ENGINE_OUTPUT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl engine -c -t bee2evp 2>&1)
        if echo "$ENGINE_OUTPUT" | grep -q "available"; then
            echo -e "${GREEN}${NC} bee2evp engine загружается через OpenSSL"
            # Показываем доступные алгоритмы
            ALGORITHMS=$(echo "$ENGINE_OUTPUT" | grep -oE "\[.*\]" | head -1)
            if [ -n "$ALGORITHMS" ]; then
                echo "   Доступные алгоритмы: $ALGORITHMS"
            fi
        else
            echo -e "${RED}${NC} bee2evp engine не загружается через OpenSSL"
            if echo "$ENGINE_OUTPUT" | grep -qi "error\|not found"; then
                ERROR_MSG=$(echo "$ENGINE_OUTPUT" | grep -i "error\|not found" | head -1)
                echo "   Ошибка: $ERROR_MSG"
            fi
        fi
    else
        echo -e "${RED}${NC} libbee2evp.so не найден"
    fi
else
    # Если контейнер не запущен, проверяем образ
    IMAGE_NAME=$($COMPOSE_CMD -f $COMPOSE_FILE config 2>/dev/null | grep -A 5 "openvpn-server:" | grep "image:" | awk '{print $2}' 2>/dev/null || echo "")
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="test-infra-openvpn-server"
    fi
    
    BEE2_LIB=$(docker run --rm "$IMAGE_NAME" find /build/build/install/lib -name "libbee2.so*" -type f 2>/dev/null | head -1)
    BEE2EVP_LIB=$(docker run --rm "$IMAGE_NAME" find /build/build/install/lib -name "libbee2evp.so*" -type f 2>/dev/null | head -1)
    
    if [ -n "$BEE2_LIB" ]; then
        echo -e "${GREEN}${NC} libbee2.so найден в образе"
    else
        echo -e "${RED}${NC} libbee2.so не найден в образе"
    fi
    
    if [ -n "$BEE2EVP_LIB" ]; then
        echo -e "${GREEN}${NC} libbee2evp.so найден в образе"
        # Проверка зависимостей
        LDD_OUTPUT=$(docker run --rm "$IMAGE_NAME" ldd "$BEE2EVP_LIB" 2>/dev/null)
        if echo "$LDD_OUTPUT" | grep -q "libbee2" && ! echo "$LDD_OUTPUT" | grep -q "not found"; then
            echo -e "${GREEN}${NC} libbee2evp прилинкован к libbee2 в образе"
        else
            echo -e "${YELLOW}${NC} Не удалось проверить зависимости в образе"
        fi
    else
        echo -e "${RED}${NC} libbee2evp.so не найден в образе"
    fi
fi
echo ""

# 5. Проверка OpenSSL
echo "5. Проверка OpenSSL..."
echo "----------------------"
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up"; then
    # Проверка версии OpenSSL
    OPENSSL_VERSION=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl version 2>&1)
    if [ -n "$OPENSSL_VERSION" ]; then
        echo -e "${GREEN}${NC} OpenSSL установлен: $OPENSSL_VERSION"
        
        # Проверка детальной информации
        OPENSSL_INFO=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl version -a 2>&1 | head -3)
        if echo "$OPENSSL_INFO" | grep -q "OpenSSL"; then
            OPENSSL_BUILT_DATE=$(echo "$OPENSSL_INFO" | grep "built on" | sed 's/.*built on //')
            if [ -n "$OPENSSL_BUILT_DATE" ]; then
                echo "   Собран: $OPENSSL_BUILT_DATE"
            fi
        fi
    else
        echo -e "${RED}${NC} OpenSSL не найден"
    fi
    
    # Проверка конфигурации OpenSSL
    OPENSSL_CONF_FILE="/etc/openvpn/openssl.cnf"
    if $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server test -f "$OPENSSL_CONF_FILE" 2>/dev/null; then
        echo -e "${GREEN}${NC} Конфигурация OpenSSL найдена: $OPENSSL_CONF_FILE"
        
        # Проверка настройки bee2evp в конфиге
        CONFIG_CONTENT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server cat "$OPENSSL_CONF_FILE" 2>/dev/null)
        if echo "$CONFIG_CONTENT" | grep -q "bee2evp"; then
            echo -e "${GREEN}${NC} bee2evp настроен в конфигурации OpenSSL"
        else
            echo -e "${YELLOW}${NC} bee2evp не найден в конфигурации OpenSSL"
        fi
    else
        echo -e "${YELLOW}${NC} Конфигурация OpenSSL не найдена: $OPENSSL_CONF_FILE"
    fi
    
    # Проверка доступности bee2evp через OpenSSL (прямая проверка)
    ENGINE_TEST=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl engine -c -t bee2evp 2>&1)
    if echo "$ENGINE_TEST" | grep -q "available"; then
        echo -e "${GREEN}${NC} bee2evp engine доступен и работает"
        # Показываем доступные алгоритмы
        ALGORITHMS=$(echo "$ENGINE_TEST" | grep -oE "\[.*\]" | head -1)
        if [ -n "$ALGORITHMS" ]; then
            echo "   Доступные алгоритмы: $ALGORITHMS"
        fi
    else
        # Проверяем список всех engines
        ENGINE_LIST=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server openssl engine 2>&1)
        if echo "$ENGINE_LIST" | grep -q "bee2evp"; then
            echo -e "${GREEN}${NC} bee2evp найден в списке engines OpenSSL"
        else
            echo -e "${YELLOW}${NC} bee2evp не найден в списке engines OpenSSL (возможно, не загружен)"
        fi
    fi
    
    # Проверка переменной окружения OPENSSL_CONF в процессе OpenVPN
    OPENVPN_PID=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server pgrep -f openvpn 2>/dev/null | head -1)
    if [ -n "$OPENVPN_PID" ]; then
        OPENSSL_CONF_ENV=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server sh -c "cat /proc/$OPENVPN_PID/environ 2>/dev/null | tr '\0' '\n' | grep '^OPENSSL_CONF='" 2>/dev/null | cut -d= -f2-)
        if [ -n "$OPENSSL_CONF_ENV" ]; then
            echo -e "${GREEN}${NC} OPENSSL_CONF установлена в процессе OpenVPN: $OPENSSL_CONF_ENV"
            # Проверяем, что файл существует
            if $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server test -f "$OPENSSL_CONF_ENV" 2>/dev/null; then
                echo -e "${GREEN}${NC} Файл конфигурации существует и доступен"
            else
                echo -e "${YELLOW}⚠${NC} Файл конфигурации не найден: $OPENSSL_CONF_ENV"
            fi
        else
            # Проверяем, установлена ли она в скрипте запуска
            OPENSSL_CONF_FROM_SCRIPT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server grep "OPENSSL_CONF=" /scripts/start-server.sh 2>/dev/null | head -1 | sed 's/.*OPENSSL_CONF=//' | tr -d '"' | tr -d "'" | tr -d ' ')
            if [ -n "$OPENSSL_CONF_FROM_SCRIPT" ]; then
                echo -e "${GREEN}${NC} OPENSSL_CONF настроена в скрипте запуска: $OPENSSL_CONF_FROM_SCRIPT"
                if $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server test -f "$OPENSSL_CONF_FROM_SCRIPT" 2>/dev/null; then
                    echo -e "${GREEN}${NC} Файл конфигурации существует"
                fi
            else
                echo -e "${YELLOW}⚠${NC} OPENSSL_CONF не найдена в окружении процесса (возможно, используется системная конфигурация)"
            fi
        fi
    else
        echo -e "${YELLOW}⚠${NC} Процесс OpenVPN не найден (нельзя проверить OPENSSL_CONF)"
    fi
else
    # Если контейнер не запущен, проверяем образ
    IMAGE_NAME=$($COMPOSE_CMD -f $COMPOSE_FILE config 2>/dev/null | grep -A 5 "openvpn-server:" | grep "image:" | awk '{print $2}' 2>/dev/null || echo "")
    if [ -z "$IMAGE_NAME" ]; then
        IMAGE_NAME="test-infra-openvpn-server"
    fi
    
    OPENSSL_VERSION=$(docker run --rm "$IMAGE_NAME" openssl version 2>&1)
    if [ -n "$OPENSSL_VERSION" ] && ! echo "$OPENSSL_VERSION" | grep -q "not found"; then
        echo -e "${GREEN}${NC} OpenSSL найден в образе: $OPENSSL_VERSION"
    else
        echo -e "${RED}${NC} OpenSSL не найден в образе"
    fi
fi
echo ""

# 6. Проверка конфигурационных файлов (тестовые конфигурации в test-infra/config/)
echo "6. Проверка конфигурационных файлов..."
echo "--------------------------------------"
if [ -f ./config/server/server.conf ]; then
    echo -e "${GREEN}${NC} server.conf найден"
else
    echo -e "${RED}${NC} server.conf не найден (ожидается: ./config/server/server.conf)"
fi

if [ -f ./config/client/client.conf ]; then
    echo -e "${GREEN}${NC} client.conf найден"
else
    echo -e "${RED}${NC} client.conf не найден (ожидается: ./config/client/client.conf)"
fi

if [ -f ./config/server/openssl.cnf ]; then
    echo -e "${GREEN}${NC} openssl.cnf (server) найден"
else
    echo -e "${RED}${NC} openssl.cnf (server) не найден (ожидается: ./config/server/openssl.cnf)"
fi

if [ -f ./config/client/openssl.cnf ]; then
    echo -e "${GREEN}${NC} openssl.cnf (client) найден"
else
    echo -e "${RED}${NC} openssl.cnf (client) не найден (ожидается: ./config/client/openssl.cnf)"
fi
echo ""

# 7. Проверка скриптов (скрипты находятся на уровень выше в ../scripts/)
echo "7. Проверка скриптов..."
echo "----------------------"
SCRIPTS=("setup-ca.sh" "start-server.sh" "start-client.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "../scripts/$script" ] && [ -x "../scripts/$script" ]; then
        echo -e "${GREEN}${NC} $script (исполняемый)"
    elif [ -f "../scripts/$script" ]; then
        echo -e "${YELLOW}${NC} $script (не исполняемый)"
    else
        echo -e "${RED}${NC} $script (не найден, ожидается: ../scripts/$script)"
    fi
done
echo ""

# 8. Проверка логов сервера (если запущен)
echo "8. Проверка логов сервера..."
echo "----------------------------"
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up"; then
    LOGS=$($COMPOSE_CMD -f $COMPOSE_FILE logs --tail=20 openvpn-server 2>/dev/null)
    
    # Проверяем наличие критических ошибок
    CRITICAL_ERRORS=$(echo "$LOGS" | grep -iE "error|fatal|failed|cannot|unable" | grep -v "VERIFY OK" | tail -5)
    if [ -n "$CRITICAL_ERRORS" ]; then
        ERROR_COUNT=$(echo "$CRITICAL_ERRORS" | wc -l)
        echo -e "${RED}${NC} Обнаружены ошибки в логах ($ERROR_COUNT):"
        echo "$CRITICAL_ERRORS" | head -3
    # Проверяем успешную инициализацию сервера
    elif echo "$LOGS" | grep -q "Initialization Sequence Completed"; then
        echo -e "${GREEN}${NC} Сервер успешно инициализирован и готов к работе"
    # Проверяем активные подключения клиентов (самый надежный признак работы)
    elif echo "$LOGS" | grep -q "client/.*Data Channel"; then
        UNIQUE_CLIENTS=$(echo "$LOGS" | grep -o "client/[^:]*" | sort -u | wc -l)
        echo -e "${GREEN}${NC} Сервер работает, активные клиенты подключены (уникальных подключений: $UNIQUE_CLIENTS)"
    # Проверяем, что сервер слушает на порту (из логов)
    elif echo "$LOGS" | grep -qE "UDPv4.*1194|TCPv4.*1194|listening|LISTEN"; then
        PORT_INFO=$(echo "$LOGS" | grep -E "UDPv4|TCPv4|listening|LISTEN" | tail -1)
        echo -e "${GREEN}${NC} Сервер запущен и слушает на порту 1194"
        echo "   $PORT_INFO"
    # Проверяем наличие процесса OpenVPN в контейнере
    elif $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server pgrep -f openvpn > /dev/null 2>&1; then
        PROCESS_COUNT=$($COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server pgrep -f openvpn | wc -l)
        echo -e "${GREEN}${NC} Сервер запущен (процесс OpenVPN работает, найдено процессов: $PROCESS_COUNT)"
    # Проверяем наличие TUN интерфейса
    elif $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-server ip addr show tun0 > /dev/null 2>&1; then
        echo -e "${GREEN}${NC} Сервер запущен (TUN интерфейс tun0 активен)"
    # Если ничего не найдено, но контейнер работает - это проблема
    else
        echo -e "${RED}${NC} Сервер запущен, но не обнаружено признаков работы OpenVPN"
        echo "   Проверьте логи вручную: $COMPOSE_CMD -f $COMPOSE_FILE logs openvpn-server"
        echo "   Последние строки логов:"
        echo "$LOGS" | tail -3 | sed 's/^/   /'
    fi
else
    echo -e "${RED}${NC} Сервер не запущен"
fi
echo ""

# 9. Проверка VPN соединения (если оба контейнера запущены)
echo "9. Проверка VPN соединения..."
echo "-----------------------------"
if $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-server | grep -q "Up" && $COMPOSE_CMD -f $COMPOSE_FILE ps openvpn-client | grep -q "Up"; then
    sleep 2
    if $COMPOSE_CMD -f $COMPOSE_FILE exec -T openvpn-client ping -c 1 10.8.0.1 > /dev/null 2>&1; then
        echo -e "${GREEN}${NC} Клиент может пинговать сервер (10.8.0.1)"
    else
        echo -e "${YELLOW}${NC} Клиент не может пинговать сервер (возможно, VPN еще не установлен)"
    fi
else
    echo -e "${YELLOW}${NC} Не все контейнеры запущены"
fi
echo ""

# Итоговая сводка
echo "=========================================="
echo "Итоговая сводка"
echo "=========================================="
echo ""
echo "Для просмотра логов:"
echo "  $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
echo ""
echo "Для остановки сервисов:"
echo "  $COMPOSE_CMD -f $COMPOSE_FILE down"
echo ""
