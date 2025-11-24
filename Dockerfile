
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

# Установка переменных окружения
ENV CMAKE_BUILD_TYPE=Release
ENV PATH=/build/build/install/bin:$PATH

# Сборка всех компонентов
RUN make all && \
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
