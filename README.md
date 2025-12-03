# OpenVPN 🚀

Проект для интеграции OpenVPN с криптографическими библиотеками bee2 и bee2evp и патчем btls.

## Как добавлены проекты

Проекты интегрированы в репозиторий с помощью **git subtree**. Это позволяет хранить код сторонних репозиториев непосредственно в нашем репозитории, сохраняя при этом возможность получать обновления из исходных источников.

### Команды добавления

```bash
git subtree add --prefix=bee2 https://github.com/agievich/bee2.git master --squash
git subtree add --prefix=bee2evp https://github.com/bcrypto/bee2evp.git master --squash
git subtree add --prefix=openvpn https://github.com/OpenVPN/openvpn.git v2.5.0 --squash
git subtree add --prefix=openssl https://github.com/openssl/openssl.git openssl-3.3.1 --squash
```

## Для чего это сделано

**Git subtree** используется вместо git submodule по следующим причинам:

- **Полная автономность** — весь код физически присутствует в репозитории, работа возможна без доступа к внешним репозиториям
- **Упрощенное развертывание** — не требуется дополнительных шагов для клонирования подмодулей
- **Безопасность** — нет риска случайной отправки изменений в сторонние репозитории
- **История изменений** — вся история проекта хранится в одном месте

## Преимущества подхода

**Независимость от внешних сервисов** — проект работает даже при недоступности GitHub или других хостингов
**Простота сборки** — достаточно одного `git clone`, все зависимости уже включены
**Контроль версий** — можно фиксировать конкретные версии зависимостей, не завися от изменений в upstream
**Локальные изменения** — можно вносить изменения в интегрированный код, они останутся в НАШЕМ РЕПОЗИТОРИИ 
**Обновляемость** — при необходимости можно получать актуальные версии из исходных репозиториев

## Обновление проектов

Для получения последних изменений из upstream-репозиториев используйте команды:

```bash
git subtree pull --prefix=bee2 https://github.com/agievich/bee2.git master --squash
git subtree pull --prefix=bee2evp https://github.com/bcrypto/bee2evp.git master --squash
git subtree pull --prefix=openvpn https://github.com/OpenVPN/openvpn.git v2.5.0 --squash
git subtree pull --prefix=openssl https://github.com/openssl/openssl.git openssl-3.3.1 --squash
```

### Примечания

- Флаг `--squash` объединяет все изменения из upstream в один коммит, что упрощает историю
- При обновлении возможны конфликты, которые нужно разрешать вручную
- Изменения, внесенные локально в интегрированные проекты, сохраняются, но не отправляются в upstream

## Структура проекта

```
openvpn/
├── bee2/          # Криптографическая библиотека
├── bee2evp/       # OpenSSL engine для bee2
├── openssl/       # Набор инструментов для протоколов TLS, Transport Layer Security (TLS, ранее SSL), Datagram TLS (DTLS) и QUIC.
├── openvpn/       # Инструмент для создания зашифрованных туннелей (VPN) между компьютерами через интернет
├── scripts/       # Скрипты для кастомной сборки Openssl + белорусская криптография
├── Dockerfile     # Dockerfile для сборки рабочего образа
└── README.md      # Документация
```

## Интегрированные проекты

| Проект | Описание | Исходный репозиторий | Ветка |
|--------|----------|---------------------|-------|
| **bee2** | Криптографическая библиотека | [agievich/bee2](https://github.com/agievich/bee2) | `master` |
| **bee2evp** | OpenSSL engine для bee2 | [bcrypto/bee2evp](https://github.com/bcrypto/bee2evp) | `master` |
| **openvpn** | Инструмент для создания зашифрованных туннелей (VPN) между компьютерами через интернет| [OpenVPN/openvpn](https://github.com/OpenVPN/openvpn) | `v2.5.0` |
| **openssl** | Набор инструментов для протоколов TLS, Transport Layer Security (TLS, ранее SSL), Datagram TLS (DTLS) и QUIC. | [openssl/openssl](https://github.com/openssl/openssl) | `openssl-3.3.1` |

## Docker: сборка и запуск 🐳

Если вы хотите собрать и запустить проект в Docker-контейнере, используйте следующие команды.

Сборка образа (рекомендуется без кэша для чистой сборки):

```bash
docker build --no-cache --progress="plain" -t its/openvpn_bc .
```

Запуск контейнера (интерактивная сессия с bash):

```bash
docker run --rm -it its/openvpn_bc bash
```

Эти команды помогут быстро получить рабочую среду для отладки и тестирования проекта. 🚀

