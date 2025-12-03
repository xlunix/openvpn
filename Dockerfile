# Dockerfile для сборки bee2, bee2evp и openvpn
FROM debian:bookworm-slim

# Установка необходимых зависимостей
RUN apt-get update \
  && apt-get install -y \
  git \
  gcc \
  cmake \
  python3 \
  doxygen \
  autoconf \
  libtool \
  pkg-config \
  libnl-genl-3-dev \
  libcap-ng-dev \
  liblzo2-dev \
  libpam0g-dev \
  liblz4-dev \
  net-tools \
  nano \
  && rm -rf /var/lib/apt/lists/*


# Создание рабочей директории
WORKDIR /usr/src/bee2evp

# Копирование исходного кода и скриптов конфигурации
COPY bee2evp/ .
RUN rm -rf ./bee2 && \
    mkdir ./bee2 && \
    mkdir ./openssl && \
    mkdir ./openvpn
COPY bee2/ ./bee2
COPY openssl/ ./openssl
COPY openvpn/ ./openvpn
COPY scripts/its_bc_build.sh ./scripts
COPY scripts/its_bc_source.sh ./scripts

# Запуск сборки Openssl v3.3.1 + bee2 + bee2evp + patch btls
ARG OPENSSL_TAG=openssl-3.3.1
RUN bash ./scripts/its_bc_build.sh  -s -b -t ${OPENSSL_TAG}
ENV LD_LIBRARY_PATH=/usr/src/bee2evp/build/local/lib
ENV PKG_CONFIG_PATH=/usr/src/bee2evp/build/local/lib/pkgconfig

# Собираем Openvpn v2.5.0 на базе ранее собранного openssl
WORKDIR /usr/src/bee2evp/openvpn
RUN autoreconf -i -v -f && bash ./configure && make && make install

# Проверка, что openvpn правильно собран и видит белорусские алгоритмы
RUN openvpn --show-tls && openvpn --show-ciphers && openvpn --show-engines

# Создание точки входа
WORKDIR /usr/src/bee2evp

# По умолчанию запускаем bash
CMD ["/bin/bash"]
