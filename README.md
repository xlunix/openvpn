# OpenVPN с поддержкой белорусских алгоритмов (Bee2 / BELT)

Проект — демонстрационная сборка OpenVPN, интегрированная с OpenSSL-engine "bee2evp" и патчами BTLS для поддержки семейства шифров и хешей, определённых в белорусских стандартах (включая алгоритмы BIGN и BELT).

README содержит инструкции по сборке и запуску сервера/клиента внутри Docker-контейнеров, примеры конфигураций и ссылки на исходный код движка `bee2evp`.

---

## 🔍 Ключевая идея

Проект показывает, как собрать OpenVPN (v2.5.0) и пропатченный OpenSSL (например, openssl-3.3.1) с интегрированным движком `bee2evp` для использования алгоритмов семейства Bee2 / BELT в TLS и шифровании канала.

Это удобно для тестирования, демонстраций и дальнейшей доработки поддержки BTLS в OpenVPN.

---

## 📁 Структура репозитория (важные папки)

- `bee2evp/` — OpenSSL-engine для Bee2 (включает исходники, патчи BTLS и скрипты сборки).
- `server/` — Dockerfile и пример конфигурации для OpenVPN-сервера.
- `client/` — Dockerfile и пример конфигурации для OpenVPN-клиента.
- `docker-compose.yaml` — готовый compose-файл, позволяющий быстро поднять сервер и клиент в контейнерах и обменяться сертификатами.
- `debian_vpn.Dockerfile` — удобный Dockerfile для быстрого построения полноценного образа OpenVPN + Bee2evp для демонстрации.

---

## 🚀 Быстрый старт (с docker-compose)

1) Склонируйте репозиторий и перейдите в корень проекта.

2) Постройте и запустите сервисы (выполните в папке проекта):

```bash
docker compose up --build
```

3) Контейнер `ovpn-server` автоматически сгенерирует CA, серверные и клиентские сертификаты в общем томе. Клиент (`ovpn-client`) зависит от сервера и попытается подключиться после генерации сертификатов.

4) Логи и запуск можно посмотреть с помощью:

```bash
docker compose logs -f ovpn-server
docker compose logs -f ovpn-client
```

> Примечание: docker-compose по умолчанию открывает порт UDP 1194 для сервера.

---

## 🧱 Как собрать вручную (Dockerfile)

Если нужен более кастомный вариант, собирайте соответствующий образ вручную.

Пример из `bee2evp/` (сборка openssl + bee2evp):

```bash
# Сборка движка bee2evp с выбранной версией OpenSSL (пример: openssl-3.3.1)
# Dockerfile `debian_vpn.Dockerfile` находится в корне проекта, поэтому указываем его напрямую
docker build --progress="plain" -f ./debian_vpn.Dockerfile -t bcrypto/bee2evp:3.3.1 --build-arg OPENSSL_TAG=openssl-3.3.1 .
```

Сборка контейнера сервера (в корне repo):

```bash
docker build -f server/Dockerfile -t ovpn-server:local .
```

Сборка контейнера клиента:

```bash
docker build -f client/Dockerfile -t ovpn-client:local .
```

---

## ⚙️ Конфигурация OpenVPN

В примерах конфигурации использованы файлы:

- `server/sample_server.conf` — конфигурация демо-сервера
- `client/sample_client.conf` — конфигурация демо-клиента

Они используют `engine bee2evp` и параметры для BELT/BTLS:

- data-ciphers / cipher: belt-cfb256
- tls-cipher: DHT-BIGN-WITH-BELT-CTR-MAC-HBELT
- auth: belt-hash

При необходимости поменяйте адрес `remote` в `client` и другие параметры под своё окружение.

---

## 🧾 Генерация сертификатов

Скрипты и Dockerfile настроены так, чтобы сервер автоматом генерировал CA, серверные и клиентские сертификаты (см. `server/entrypoint.sh` и `debian_vpn.Dockerfile`).

Если вы хотите готовые сертификаты — подключите их в томе `ovpn_data` или подмонтируйте свою директорию с `/etc/openvpn/certs`.

---

## 🔎 Отладка и проверка

Ниже — быстрые команды, которые помогут проверить доступность движка `bee2evp`, список шифров и TLS-возможности в вашей сборке OpenVPN.

### Локально / внутри образа

Запуск на машине или внутри контейнера с установленным `openvpn`:

```bash
# Показать доступные OpenSSL engines, в том числе "bee2evp"
openvpn --show-engines

# Показать все поддерживаемые OpenVPN шифры / TLS-шифры
openvpn --show-ciphers

# Показать набор TLS-опций и поддерживаемые параметры TLS
openvpn --show-tls
```

### В запущенном Docker-контейнере

Если вы используете `docker compose up` (в корне проекта), то можно выполнить команды внутри работающего контейнера сервера:

```bash
docker compose exec ovpn-server openvpn --show-engines
docker compose exec ovpn-server openvpn --show-ciphers
docker compose exec ovpn-server openvpn --show-tls
```

Если контейнер уже запущен, но вы предпочитаете docker cli напрямую:

```bash
docker exec -it ovpn-server openvpn --show-engines
```

Или запустить временный контейнер на базе локального образа:

```bash
docker run --rm -it ovpn-server:local openvpn --show-engines
```

- Логи контейнера — `docker compose logs -f <service>`.

---

## 📚 Полезные ссылки

- Bee2evp (движок OpenSSL): https://github.com/bcrypto/bee2evp
- Документы по BTLS / STB 34.101.65 (региональные стандарты) — смотрите папку `bee2evp/btls` для применённых патчей.

---

## 🧑‍💻 Для разработчиков

Проект использует стандартную структуру демонстрационного репозитория и включает набор скриптов и Dockerfile, которые позволяют быстро тестировать интеграцию OpenVPN с Bee2/OpenSSL.

Если вы хотите внести изменения — поработайте в ветке, создайте PR и опишите цель изменений и тест-кейсы.

---

## 📜 Лицензия

Проект использует лицензионные положения вложенных проектов (см. `bee2evp/LICENSE.txt`). Подробности см. в исходных подмодулях и файлах лицензий.

