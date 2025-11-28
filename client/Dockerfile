FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y \
  git gcc cmake python3 doxygen autoconf libtool pkg-config libnl-genl-3-dev libcap-ng-dev liblzo2-dev libpam0g-dev liblz4-dev net-tools nano iputils-ping\
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/bee2evp
COPY bee2evp .


ARG OPENSSL_TAG
RUN bash ./scripts/build.sh -s -b -t ${OPENSSL_TAG}

ENV LD_LIBRARY_PATH=/usr/src/bee2evp/build/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=/usr/src/bee2evp/build/local/lib/pkgconfig:$PKG_CONFIG_PATH

RUN git clone --branch v2.5.0 https://github.com/OpenVPN/openvpn.git
WORKDIR /usr/src/bee2evp/openvpn
RUN autoreconf -i -v -f && ./configure && make && make install

RUN openvpn --show-tls && openvpn --show-ciphers && openvpn --show-engines

COPY client/sample_client.conf /etc/openvpn/client.conf
COPY client/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]