
# Dockerfile для сборки bee2, bee2evp и openvpn
FROM debian

# Установка необходимых зависимостей
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libssl-dev \
    liblz4-dev \
    liblzo2-dev \
    libpkcs11-helper1-dev \
    libcap-ng-dev \
    libnl-genl-3-dev \
    python3 \
    iputils-ping \
    netcat-openbsd \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /build

# Копирование исходного кода
COPY bee2/ /build/bee2/
COPY bee2evp/ /build/bee2evp/
COPY openvpn/ /build/openvpn/
COPY Makefile /build/

# Копирование скриптов
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Установка переменных окружения
ENV CMAKE_BUILD_TYPE=Release
ENV PATH=/build/build/install/bin:$PATH

# Сборка всех компонентов (bee2 -> openssl с патчами -> bee2evp -> openvpn)
RUN echo "=== Сборка всех компонентов ===" && \
    echo "Порядок: bee2 -> OpenSSL с патчами для bee2evp -> bee2evp -> openvpn" && \
    make all 2>&1 | tee /tmp/build.log && \
    echo "=== Проверка собранных компонентов ===" && \
    echo "OpenSSL:" && \
    ls -lh /build/build/install/bin/openssl 2>/dev/null || (echo "  OpenSSL не найден в /build/build/install/bin/" && tail -20 /tmp/build.log) && \
    echo "Библиотеки OpenSSL:" && \
    ls -lh /build/build/install/lib/libssl.so* /build/build/install/lib/libcrypto.so* 2>/dev/null | head -4 || echo "  Библиотеки OpenSSL не найдены" && \
    echo "bee2evp:" && \
    ls -lh /build/build/install/lib/libbee2evp.so* 2>/dev/null || echo "  libbee2evp не найден" && \
    echo "OpenVPN:" && \
    find /build -name openvpn -type f -executable 2>/dev/null | head -1 | xargs ls -lh 2>/dev/null || (echo "  OpenVPN не найден" && tail -30 /tmp/build.log) && \
    export LD_LIBRARY_PATH=/build/build/install/lib:$LD_LIBRARY_PATH

# Настройка OpenSSL для использования bee2evp engine
RUN if [ -f /build/build/install/openssl.cnf.dist ]; then \
        cp /build/build/install/openssl.cnf.dist /build/build/install/openssl.cnf; \
    fi && \
    if [ -f /build/build/install/openssl.cnf ]; then \
        echo "" >> /build/build/install/openssl.cnf && \
        echo "openssl_conf = openssl_init" >> /build/build/install/openssl.cnf && \
        echo "[openssl_init]" >> /build/build/install/openssl.cnf && \
        echo "engines = engine_section" >> /build/build/install/openssl.cnf && \
        echo "[engine_section]" >> /build/build/install/openssl.cnf && \
        echo "bee2evp = bee2evp_section" >> /build/build/install/openssl.cnf && \
        echo "[bee2evp_section]" >> /build/build/install/openssl.cnf && \
        echo "engine_id = bee2evp" >> /build/build/install/openssl.cnf && \
        echo "dynamic_path = /build/build/install/lib/libbee2evp.so" >> /build/build/install/openssl.cnf && \
        echo "default_algorithms = ALL" >> /build/build/install/openssl.cnf; \
    fi

# Создание точки входа
WORKDIR /build/build/install

# По умолчанию запускаем bash
CMD ["/bin/bash"]
