# Makefile для сборки bee2, OpenSSL с патчами, bee2evp и openvpn
# Порядок сборки: bee2 -> openssl -> bee2evp -> openvpn

# Переменные
BUILD_DIR := build
INSTALL_DIR := $(BUILD_DIR)/install
BEE2_BUILD_DIR := $(BUILD_DIR)/bee2
OPENSSL_BUILD_DIR := $(BUILD_DIR)/openssl
OPENSSL_SOURCE_DIR := $(BUILD_DIR)/openssl-src
BEE2EVP_BUILD_DIR := $(BUILD_DIR)/bee2evp
OPENVPN_BUILD_DIR := $(BUILD_DIR)/openvpn

# Тег OpenSSL для сборки (должен соответствовать патчу в bee2evp/btls/patch/)
OPENSSL_TAG ?= openssl-3.3.1

# Получаем абсолютный путь к корню проекта
# CURDIR - это текущая директория, где запущен make
INSTALL_DIR_ABS := $(CURDIR)/$(INSTALL_DIR)

# Пути к установленным библиотекам
BEE2_LIB_DIR := $(INSTALL_DIR_ABS)/lib
BEE2_INCLUDE_DIR := $(INSTALL_DIR_ABS)/include
BEE2EVP_LIB_DIR := $(INSTALL_DIR_ABS)/lib
BEE2EVP_INCLUDE_DIR := $(INSTALL_DIR_ABS)/include

# Флаги сборки
CMAKE_BUILD_TYPE ?= Release
CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
               -DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR_ABS) \
               -DCMAKE_INSTALL_LIBDIR=lib

# По умолчанию собираем все
.PHONY: all
all: bee2 openssl bee2evp openvpn

# Сборка bee2
.PHONY: bee2
bee2: $(BEE2_BUILD_DIR)/.build_done

$(BEE2_BUILD_DIR)/.build_done:
	@echo "=== Сборка bee2 ==="
	@echo "INSTALL_DIR_ABS=$(INSTALL_DIR_ABS)"
	mkdir -p $(BEE2_BUILD_DIR)
	@mkdir -p $(INSTALL_DIR_ABS)/lib $(INSTALL_DIR_ABS)/include
	cd $(BEE2_BUILD_DIR) && \
	cmake $(CMAKE_FLAGS) \
	      -DBUILD_PIC=ON \
	      -DBUILD_SHARED_LIBS=OFF \
	      -DBUILD_CMD=OFF \
	      -DBUILD_TESTS=OFF \
	      -DBUILD_DOC=OFF \
	      ../../bee2
	cd $(BEE2_BUILD_DIR) && cmake --build . --config $(CMAKE_BUILD_TYPE)
	cd $(BEE2_BUILD_DIR) && cmake --install .
	@# Проверяем, куда установилась библиотека, и копируем в нужное место, если нужно
	@if [ ! -f $(BEE2_LIB_DIR)/libbee2_static.a ]; then \
		echo "Библиотека не в ожидаемом месте, ищем..."; \
		FOUND_LIB=$$(find $(BUILD_DIR) -name "libbee2_static.a" 2>/dev/null | head -1); \
		if [ -n "$$FOUND_LIB" ]; then \
			echo "Найдена библиотека в $$FOUND_LIB, копируем в $(BEE2_LIB_DIR)"; \
			mkdir -p $(BEE2_LIB_DIR); \
			cp $$FOUND_LIB $(BEE2_LIB_DIR)/; \
		fi; \
	fi
	@# Копируем заголовочные файлы, если нужно
	@if [ ! -d $(BEE2_INCLUDE_DIR)/bee2 ]; then \
		FOUND_INC=$$(find $(BUILD_DIR) -type d -name "bee2" -path "*/include/*" 2>/dev/null | head -1); \
		if [ -n "$$FOUND_INC" ]; then \
			echo "Найдены заголовки в $$FOUND_INC, копируем в $(BEE2_INCLUDE_DIR)"; \
			mkdir -p $(BEE2_INCLUDE_DIR); \
			cp -r $$FOUND_INC $(BEE2_INCLUDE_DIR)/; \
		fi; \
	fi
	touch $@

# Сборка OpenSSL с патчами для bee2evp (зависит от bee2)
.PHONY: openssl
openssl: bee2 $(OPENSSL_BUILD_DIR)/.build_done

$(OPENSSL_BUILD_DIR)/.build_done: $(BEE2_BUILD_DIR)/.build_done
	@echo "=== Сборка OpenSSL с патчами для bee2evp ==="
	@# Проверяем наличие патча (проверяем из корня проекта)
	@PATCH_FILE="$(CURDIR)/bee2evp/btls/patch/$(OPENSSL_TAG).patch"; \
	if [ ! -f "$$PATCH_FILE" ]; then \
		echo "Ошибка: патч для OpenSSL $(OPENSSL_TAG) не найден: $$PATCH_FILE"; \
		echo "Доступные патчи:"; \
		ls -1 $(CURDIR)/bee2evp/btls/patch/*.patch 2>/dev/null | sed 's/.*\//  /' || echo "  (не найдено)"; \
		exit 1; \
	fi
	@# Скачиваем OpenSSL, если еще не скачан
	@if [ ! -d "$(OPENSSL_SOURCE_DIR)" ]; then \
		echo "Скачивание OpenSSL $(OPENSSL_TAG)..."; \
		mkdir -p $(OPENSSL_SOURCE_DIR); \
		git clone -b $(OPENSSL_TAG) --depth 1 https://github.com/openssl/openssl.git $(OPENSSL_SOURCE_DIR) || \
		(echo "Ошибка при скачивании OpenSSL. Проверьте тег: $(OPENSSL_TAG)" && exit 1); \
	fi
	@# Применяем патчи
	@echo "Применение патчей для OpenSSL..."; \
	IS_OPENSSL_3=0; \
	if echo "$(OPENSSL_TAG)" | grep -qE "openssl-3|OpenSSL_3"; then \
		IS_OPENSSL_3=1; \
	fi; \
	cd $(OPENSSL_SOURCE_DIR) && \
	if [ $$IS_OPENSSL_3 -eq 1 ]; then \
		cp $(CURDIR)/bee2evp/btls/btls.c ./ssl/ && \
		cp $(CURDIR)/bee2evp/btls/btls.h ./ssl/ && \
		cat $(CURDIR)/bee2evp/btls/objects.txt >> ./crypto/objects/objects.txt; \
	else \
		cp $(CURDIR)/bee2evp/btls/legacy/btls.c ./ssl/ && \
		cp $(CURDIR)/bee2evp/btls/legacy/btls.h ./ssl/; \
	fi && \
	echo "Попытка применения патча для BTLS поддержки..." && \
	if git apply $(CURDIR)/bee2evp/btls/patch/$(OPENSSL_TAG).patch 2>&1; then \
		echo " Патч успешно применен (BTLS поддержка включена)"; \
		PATCH_APPLIED=1; \
	else \
		echo " ОШИБКА: Патч не применен (BTLS поддержка недоступна)"; \
		echo " Для поддержки BTLS патч ОБЯЗАТЕЛЕН!"; \
		echo " Проверьте совместимость патча с OpenSSL $(OPENSSL_TAG)"; \
		echo " Доступные патчи:"; \
		ls -1 $(CURDIR)/bee2evp/btls/patch/*.patch 2>/dev/null | sed 's/.*\//  /' || echo "  (не найдено)"; \
		echo " Сборка OpenSSL прервана, так как BTLS поддержка обязательна"; \
		exit 1; \
	fi
	@# Собираем OpenSSL
	@echo "Сборка OpenSSL..."; \
	IS_OPENSSL_3=0; \
	if echo "$(OPENSSL_TAG)" | grep -qE "openssl-3|OpenSSL_3"; then \
		IS_OPENSSL_3=1; \
	fi; \
	mkdir -p $(OPENSSL_BUILD_DIR); \
	cd $(OPENSSL_BUILD_DIR) && \
	OSSL_CONFIG="linux-x86_64"; \
	CONFIGURE_SCRIPT="$(CURDIR)/$(OPENSSL_SOURCE_DIR)/Configure"; \
	if [ ! -f "$$CONFIGURE_SCRIPT" ]; then \
		echo "Ошибка: Configure не найден: $$CONFIGURE_SCRIPT"; \
		echo "Ищем Configure в других местах..."; \
		find $(CURDIR)/$(BUILD_DIR) -name Configure -type f 2>/dev/null | head -3; \
		exit 1; \
	fi && \
	if [ "$(CMAKE_BUILD_TYPE)" = "Debug" ]; then \
		$$CONFIGURE_SCRIPT $$OSSL_CONFIG shared --prefix=$(INSTALL_DIR_ABS) --openssldir=$(INSTALL_DIR_ABS) --libdir=lib --debug; \
	else \
		$$CONFIGURE_SCRIPT $$OSSL_CONFIG shared --prefix=$(INSTALL_DIR_ABS) --openssldir=$(INSTALL_DIR_ABS) --libdir=lib; \
	fi && \
	if [ $$IS_OPENSSL_3 -eq 1 ]; then \
		make update || (echo "Ошибка: make update не выполнен" && exit 1); \
	fi && \
	NPROC=$$(nproc 2>/dev/null || echo 4); \
	echo "Сборка OpenSSL с использованием $$NPROC потоков..."; \
	make -j$$NPROC all || (echo "Ошибка при сборке OpenSSL" && exit 1) && \
	make install || (echo "Ошибка при установке OpenSSL" && exit 1)
	@# Проверяем, что библиотеки установлены
	@if [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.so ] && [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.a ]; then \
		echo "Ошибка: OpenSSL не установлен в $(INSTALL_DIR_ABS)/lib"; \
		exit 1; \
	fi
	@echo "OpenSSL успешно собран и установлен в $(INSTALL_DIR_ABS)"
	touch $@

# Сборка bee2evp (зависит от bee2 и openssl)
.PHONY: bee2evp
bee2evp: bee2 openssl $(BEE2EVP_BUILD_DIR)/.build_done

$(BEE2EVP_BUILD_DIR)/.build_done: $(BEE2_BUILD_DIR)/.build_done $(OPENSSL_BUILD_DIR)/.build_done
	@echo "=== Сборка bee2evp ==="
	@# Проверяем, что библиотека bee2 установлена
	@if [ ! -f $(BEE2_LIB_DIR)/libbee2_static.a ]; then \
		echo "Ошибка: библиотека bee2 не найдена в $(BEE2_LIB_DIR)"; \
		echo "Ищем библиотеку в других местах..."; \
		find $(BUILD_DIR) -name "libbee2_static.a" 2>/dev/null | head -5; \
		echo "Список файлов в $(BEE2_LIB_DIR):"; \
		ls -la $(BEE2_LIB_DIR) 2>/dev/null || echo "Директория не существует"; \
		exit 1; \
	fi
	@# Проверяем, что OpenSSL установлен
	@if [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.so ] && [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.a ]; then \
		echo "Ошибка: OpenSSL не найден в $(INSTALL_DIR_ABS)/lib"; \
		echo "Сначала соберите OpenSSL: make openssl"; \
		exit 1; \
	fi
	mkdir -p $(BEE2EVP_BUILD_DIR)
	cd $(BEE2EVP_BUILD_DIR) && \
	cmake $(CMAKE_FLAGS) \
	      -DBEE2_LIBRARY_DIRS=$(BEE2_LIB_DIR) \
	      -DBEE2_INCLUDE_DIRS=$(BEE2_INCLUDE_DIR) \
	      -DOPENSSL_LIBRARY_DIRS=$(INSTALL_DIR_ABS)/lib \
	      -DOPENSSL_INCLUDE_DIRS=$(INSTALL_DIR_ABS)/include \
	      -DCMAKE_PREFIX_PATH=$(INSTALL_DIR_ABS) \
	      -DCMAKE_LIBRARY_PATH=$(BEE2_LIB_DIR):$(INSTALL_DIR_ABS)/lib \
	      -DBUILD_DOC=OFF \
	      -DBUILD_TESTS=OFF \
	      ../../bee2evp
	@# Если библиотека не найдена, устанавливаем её вручную
	@if grep -q "BEE2_LIBRARIES.*NOTFOUND" $(BEE2EVP_BUILD_DIR)/CMakeCache.txt 2>/dev/null; then \
		echo "Библиотека не найдена, устанавливаем вручную..."; \
		cd $(BEE2EVP_BUILD_DIR) && \
		cmake -DBEE2_LIBRARIES=$(BEE2_LIB_DIR)/libbee2_static.a .; \
	fi
	cd $(BEE2EVP_BUILD_DIR) && cmake --build . --config $(CMAKE_BUILD_TYPE)
	cd $(BEE2EVP_BUILD_DIR) && cmake --install .
	touch $@

# Сборка openvpn (зависит от bee2evp и openssl)
.PHONY: openvpn
openvpn: bee2evp openssl $(OPENVPN_BUILD_DIR)/.build_done

$(OPENVPN_BUILD_DIR)/.build_done: $(BEE2EVP_BUILD_DIR)/.build_done $(OPENSSL_BUILD_DIR)/.build_done
	@echo "=== Сборка openvpn ==="
	@# Проверяем наличие OpenSSL в установочной директории
	@if [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.so ] && [ ! -f $(INSTALL_DIR_ABS)/lib/libssl.a ]; then \
		echo "Ошибка: OpenSSL не найден в $(INSTALL_DIR_ABS)/lib"; \
		echo "Сначала соберите OpenSSL: make openssl"; \
		exit 1; \
	fi
	@echo "OpenSSL найден в установочной директории: $(INSTALL_DIR_ABS)"; \
	echo "Будут использованы пути к собранному OpenSSL с патчами для bee2evp"
	mkdir -p $(OPENVPN_BUILD_DIR)
	@# Собираем CMake флаги
	@OPENSSL_FLAGS=""; \
	if [ -f $(INSTALL_DIR_ABS)/lib/libssl.so ] || [ -f $(INSTALL_DIR_ABS)/lib/libssl.a ]; then \
		OPENSSL_FLAGS="-DOPENSSL_ROOT_DIR=$(INSTALL_DIR_ABS) -DOPENSSL_INCLUDE_DIR=$(INSTALL_DIR_ABS)/include -DCMAKE_PREFIX_PATH=$(INSTALL_DIR_ABS)"; \
		if [ -f $(INSTALL_DIR_ABS)/lib/libcrypto.so ]; then \
			OPENSSL_FLAGS="$$OPENSSL_FLAGS -DOPENSSL_CRYPTO_LIBRARY=$(INSTALL_DIR_ABS)/lib/libcrypto.so"; \
		fi; \
		if [ -f $(INSTALL_DIR_ABS)/lib/libssl.so ]; then \
			OPENSSL_FLAGS="$$OPENSSL_FLAGS -DOPENSSL_SSL_LIBRARY=$(INSTALL_DIR_ABS)/lib/libssl.so"; \
		fi; \
	fi; \
	cd $(OPENVPN_BUILD_DIR) && \
	cmake $(CMAKE_FLAGS) \
	      -DUNSUPPORTED_BUILDS=ON \
	      -DENABLE_LZ4=ON \
	      -DENABLE_LZO=ON \
	      -DENABLE_PKCS11=ON \
	      -DBUILD_TESTING=OFF \
	      $$OPENSSL_FLAGS \
	      ../../openvpn
	cd $(OPENVPN_BUILD_DIR) && cmake --build . --config $(CMAKE_BUILD_TYPE)
	cd $(OPENVPN_BUILD_DIR) && cmake --install .
	touch $@

# Очистка
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

# Очистка только openvpn
.PHONY: clean-openvpn
clean-openvpn:
	rm -rf $(OPENVPN_BUILD_DIR)

# Очистка только bee2evp
.PHONY: clean-bee2evp
clean-bee2evp:
	rm -rf $(BEE2EVP_BUILD_DIR)

# Очистка только bee2
.PHONY: clean-bee2
clean-bee2:
	rm -rf $(BEE2_BUILD_DIR)

# Очистка только openssl
.PHONY: clean-openssl
clean-openssl:
	rm -rf $(OPENSSL_BUILD_DIR) $(OPENSSL_SOURCE_DIR)

# Пересборка (очистка и сборка)
.PHONY: rebuild
rebuild: clean all

# Показать информацию о собранных библиотеках
.PHONY: info
info:
	@echo "=== Информация о собранных библиотеках ==="
	@echo "Установочная директория: $(INSTALL_DIR)"
	@if [ -d $(INSTALL_DIR) ]; then \
		echo "\nБиблиотеки:"; \
		find $(INSTALL_DIR) -name "*.so*" -o -name "*.a" 2>/dev/null | head -20; \
		echo "\nИсполняемые файлы:"; \
		find $(INSTALL_DIR) -type f -executable 2>/dev/null | head -10; \
	fi

# Помощь
.PHONY: help
help:
	@echo "Доступные цели:"
	@echo "  all          - Собрать все компоненты (bee2, openssl, bee2evp, openvpn)"
	@echo "  bee2         - Собрать только bee2"
	@echo "  openssl      - Собрать OpenSSL с патчами для bee2evp (требует bee2)"
	@echo "  bee2evp      - Собрать bee2evp (требует bee2 и openssl)"
	@echo "  openvpn      - Собрать openvpn (требует bee2evp и openssl)"
	@echo "  clean        - Удалить все собранные файлы"
	@echo "  clean-bee2   - Удалить только bee2"
	@echo "  clean-openssl - Удалить только openssl"
	@echo "  clean-bee2evp - Удалить только bee2evp"
	@echo "  clean-openvpn - Удалить только openvpn"
	@echo "  rebuild      - Полная пересборка"
	@echo "  info         - Показать информацию о собранных библиотеках"
	@echo "  help         - Показать эту справку"
	@echo ""
	@echo "Переменные:"
	@echo "  CMAKE_BUILD_TYPE - Тип сборки (Release, Debug) [по умолчанию: Release]"
	@echo "  OPENSSL_TAG - Тег OpenSSL для сборки [по умолчанию: openssl-3.3.1]"
	@echo ""
	@echo "Примеры:"
	@echo "  make                    # Собрать все в режиме Release"
	@echo "  make CMAKE_BUILD_TYPE=Debug  # Собрать все в режиме Debug"
	@echo "  make bee2               # Собрать только bee2"
	@echo "  make clean              # Очистить все"
