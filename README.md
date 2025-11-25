# OpenVPN

Проект для интеграции OpenVPN с криптографическими библиотеками белорусского алгоритма шифрования Belt.


## Как собрать рабочий контейнер

Так как для работы OpenVPN необходим пропатченный OpenSSL с BTLS, был доработан Dockerfile на базе готового контейнера с собранным openssl v3.3.1 (Оригинал dockerfiles/debian.Dockerfile). Все необходимые изменения вплоть до сборки OpenVPN были внесены в файл dockerfiles/debian.Dockerfile. Для сборки выполнить следующую команду в директории bee2evp:
```
# OpenVPN 2.5.0 + Lib OpenSSL 3.3.1 + Bee2evp engine
docker build --progress="plain" -f dockerfiles/debian_vpn.Dockerfile \
   -t bcrypto/bee2evp:3.3.1 --build-arg OPENSSL_TAG=openssl-3.3.1 . 
```


## Структура проекта

```
openvpn/
├── bee2evp/       # OpenSSL engine для bee2
└── README.md      # Документация
```

## Интегрированные проекты

| Проект | Описание | Исходный репозиторий | Ветка |
|--------|----------|---------------------|-------|
| **bee2evp** | OpenSSL engine для bee2 | [bcrypto/bee2evp](https://github.com/bcrypto/bee2evp) | `master` |
