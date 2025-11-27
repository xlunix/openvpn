FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y \
  git gcc cmake python3 doxygen autoconf libtool pkg-config libnl-genl-3-dev libcap-ng-dev liblzo2-dev libpam0g-dev liblz4-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/bee2evp
COPY bee2evp .

ARG OPENSSL_TAG
RUN bash ./scripts/build.sh -s -b -t ${OPENSSL_TAG}

ENV LD_LIBRARY_PATH=/usr/src/bee2evp/build/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=/usr/src/bee2evp/build/local/lib/pkgconfig:$PKG_CONFIG_PATH

RUN git clone --branch v2.5.0 https://github.com/OpenVPN/openvpn.git
WORKDIR /usr/src/bee2evp/openvpn
RUN autoreconf -i -v -f && bash ./configure && make && make install

RUN openvpn --show-tls && openvpn --show-ciphers && openvpn --show-engines

WORKDIR /usr/src/bee2evp/config_openvpn

# Генерация CA (Можно использовать другие параметры)
RUN openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out ca.key && \
    openssl req -new -x509 -engine bee2evp -key ca.key -out ca.crt -days 3650 -subj "/CN=MyCA" -sha256

# Генерация серверных сертификатов (Можно использовать другие параметры)
RUN openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out server.key && \
    openssl req -new -engine bee2evp -key server.key -out server.csr -subj "/CN=Server" && \
    openssl x509 -req -engine bee2evp -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256

# Генерация клиентских сертификатов (Можно использовать другие параметры)
RUN openssl genpkey -engine bee2evp -algorithm bign -pkeyopt params:bign-curve256v1 -out client.key && \
    openssl req -new -engine bee2evp -key client.key -out client.csr -subj "/CN=Client" && \
    openssl x509 -req -engine bee2evp -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256

COPY sample_server.conf ./server.conf
COPY sample_client.conf ./client.conf

