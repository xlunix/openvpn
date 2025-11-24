# Makefile для сборки bee2, bee2evp и openvpn
# Порядок сборки: bee2 -> bee2evp -> openvpn

# Переменные
BUILD_DIR := build
INSTALL_DIR := $(BUILD_DIR)/install
BEE2_BUILD_DIR := $(BUILD_DIR)/bee2
BEE2EVP_BUILD_DIR := $(BUILD_DIR)/bee2evp
OPENVPN_BUILD_DIR := $(BUILD_DIR)/openvpn

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
all: bee2 bee2evp openvpn

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

# Сборка bee2evp (зависит от bee2)
.PHONY: bee2evp
bee2evp: bee2 $(BEE2EVP_BUILD_DIR)/.build_done

$(BEE2EVP_BUILD_DIR)/.build_done: $(BEE2_BUILD_DIR)/.build_done
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
	mkdir -p $(BEE2EVP_BUILD_DIR)
	cd $(BEE2EVP_BUILD_DIR) && \
	cmake $(CMAKE_FLAGS) \
	      -DBEE2_LIBRARY_DIRS=$(BEE2_LIB_DIR) \
	      -DBEE2_INCLUDE_DIRS=$(BEE2_INCLUDE_DIR) \
	      -DCMAKE_PREFIX_PATH=$(INSTALL_DIR) \
	      -DCMAKE_LIBRARY_PATH=$(BEE2_LIB_DIR) \
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

# Сборка openvpn (зависит от bee2evp)
.PHONY: openvpn
openvpn: bee2evp $(OPENVPN_BUILD_DIR)/.build_done

$(OPENVPN_BUILD_DIR)/.build_done: $(BEE2EVP_BUILD_DIR)/.build_done
	@echo "=== Сборка openvpn ==="
	mkdir -p $(OPENVPN_BUILD_DIR)
	cd $(OPENVPN_BUILD_DIR) && \
	cmake $(CMAKE_FLAGS) \
	      -DUNSUPPORTED_BUILDS=ON \
	      -DENABLE_LZ4=ON \
	      -DENABLE_LZO=ON \
	      -DENABLE_PKCS11=ON \
	      -DBUILD_TESTING=OFF \
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
	@echo "  all          - Собрать все компоненты (bee2, bee2evp, openvpn)"
	@echo "  bee2         - Собрать только bee2"
	@echo "  bee2evp      - Собрать bee2evp (требует bee2)"
	@echo "  openvpn      - Собрать openvpn (требует bee2evp)"
	@echo "  clean        - Удалить все собранные файлы"
	@echo "  clean-bee2   - Удалить только bee2"
	@echo "  clean-bee2evp - Удалить только bee2evp"
	@echo "  clean-openvpn - Удалить только openvpn"
	@echo "  rebuild      - Полная пересборка"
	@echo "  info         - Показать информацию о собранных библиотеках"
	@echo "  help         - Показать эту справку"
	@echo ""
	@echo "Переменные:"
	@echo "  CMAKE_BUILD_TYPE - Тип сборки (Release, Debug) [по умолчанию: Release]"
	@echo ""
	@echo "Примеры:"
	@echo "  make                    # Собрать все в режиме Release"
	@echo "  make CMAKE_BUILD_TYPE=Debug  # Собрать все в режиме Debug"
	@echo "  make bee2               # Собрать только bee2"
	@echo "  make clean              # Очистить все"
