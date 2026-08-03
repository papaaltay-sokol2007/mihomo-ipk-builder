#!/bin/bash
#
# Mihomo IPK Auto-Builder for Entware (Keenetic)
# Собирает пакеты для aarch64-3.10 и mipsel-3.4 одновременно.
# Поддерживает суффикс версии (например, -fix-pppoe)
#
# Источник: https://github.com/papaaltay-sokol2007/mihomo
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BRANCH="${1:-Alpha}"
COMPRESS_UPX="${2:-true}"
VERSION_SUFFIX="${3:-}"   # например, "-fix-pppoe"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Mihomo IPK Auto-Builder              ${NC}"
echo -e "${GREEN}  Ветка:         ${BRANCH}             ${NC}"
echo -e "${GREEN}  UPX сжатие:    ${COMPRESS_UPX}       ${NC}"
echo -e "${GREEN}  Суффикс версии:${VERSION_SUFFIX:-<нет>}${NC}"
echo -e "${GREEN}  Целевые архитектуры: aarch64, mipsel${NC}"
echo -e "${GREEN}========================================${NC}"

# Установка зависимостей
sudo apt update -qq
sudo apt install -y -qq git golang make tar gzip file wget curl
if [ "$COMPRESS_UPX" = "true" ] && ! command -v upx &> /dev/null; then
    sudo apt install -y -qq upx
fi

# Папка для результатов
OUTPUT_DIR="$HOME/mihomo-ipk"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
echo -e "${GREEN}Пакеты будут сохранены в: $OUTPUT_DIR${NC}"

# Временная рабочая директория
WORK_DIR=$(mktemp -d -t mihomo-build-XXXXXX)
echo -e "${GREEN}Рабочая директория: $WORK_DIR${NC}"
cd "$WORK_DIR"

# Клонирование репозитория
SOURCE_REPO="https://github.com/papaaltay-sokol2007/mihomo.git"
echo -e "${YELLOW}Клонирование ветки ${BRANCH} из ${SOURCE_REPO}...${NC}"
git clone --depth 1 --branch "${BRANCH}" "${SOURCE_REPO}" src
cd src

# Определение версии
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILDTIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Формируем финальную версию с суффиксом
if [ -n "$VERSION_SUFFIX" ]; then
    FULL_VERSION="${VERSION}${VERSION_SUFFIX}-${COMMIT}"
    DISPLAY_VERSION="${VERSION}${VERSION_SUFFIX}"
else
    FULL_VERSION="${VERSION}-${COMMIT}"
    DISPLAY_VERSION="${VERSION}"
fi

echo -e "${GREEN}Версия: ${DISPLAY_VERSION} (коммит ${COMMIT})${NC}"

# Функция сборки для одной архитектуры
build_for_arch() {
    local GOARCH="$1"
    local IPK_ARCH="$2"
    local ARCH_NAME="$3"

    echo -e "${YELLOW}Сборка для ${ARCH_NAME} (GOARCH=${GOARCH}, IPK_ARCH=${IPK_ARCH})...${NC}"

    CGO_ENABLED=0 GOOS=linux GOARCH="${GOARCH}" \
    go build -tags with_gvisor -trimpath \
    -ldflags="-w -s -buildid= \
    -X 'github.com/metacubex/mihomo/constant.Version=${DISPLAY_VERSION}' \
    -X 'github.com/metacubex/mihomo/constant.BuildTime=${BUILDTIME}'" \
    -o mihomo

    if [ ! -f mihomo ]; then
        echo -e "${RED}Ошибка сборки для ${ARCH_NAME}!${NC}"
        exit 1
    fi
    echo -e "${GREEN}Бинарник собран, размер: $(du -h mihomo | cut -f1)${NC}"

    if [ "$COMPRESS_UPX" = "true" ] && command -v upx &> /dev/null; then
        echo -e "${YELLOW}Сжатие UPX для ${ARCH_NAME}...${NC}"
        upx --lzma --best mihomo || true
        echo -e "${GREEN}После UPX: $(du -h mihomo | cut -f1)${NC}"
    fi

    PKG_DIR="${WORK_DIR}/package_${ARCH_NAME}"
    mkdir -p "${PKG_DIR}/CONTROL"
    mkdir -p "${PKG_DIR}/DATA/opt/bin"
    mkdir -p "${PKG_DIR}/DATA/opt/etc/mihomo"
    mkdir -p "${PKG_DIR}/DATA/opt/etc/init.d"

    cp mihomo "${PKG_DIR}/DATA/opt/bin/mihomo"
    chmod 755 "${PKG_DIR}/DATA/opt/bin/mihomo"

    touch "${PKG_DIR}/DATA/opt/etc/mihomo/config.yaml"

    cat > "${PKG_DIR}/DATA/opt/etc/init.d/S99mihomo" << 'EOF'
#!/bin/sh
ENABLED=yes
PROCS=mihomo
ARGS="-d /opt/etc/mihomo"
PREARGS=""
DESC="Mihomo daemon"
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. /opt/etc/init.d/rc.func
EOF
    chmod 755 "${PKG_DIR}/DATA/opt/etc/init.d/S99mihomo"

    cat > "${PKG_DIR}/CONTROL/control" << EOF
Package: mihomo
Version: ${FULL_VERSION}
Description: Mihomo (Clash.Meta) core binary for Entware (${BRANCH} branch)
Section: net
Priority: optional
Maintainer: Builder <auto@local>
Architecture: ${IPK_ARCH}
Depends: libc, curl
Source: https://github.com/papaaltay-sokol2007/mihomo/tree/${BRANCH}
EOF

    cat > "${PKG_DIR}/CONTROL/postinst" << 'EOF'
#!/bin/sh
if [ -x /opt/etc/init.d/S99mihomo ]; then
    /opt/etc/init.d/S99mihomo enable
    /opt/etc/init.d/S99mihomo start
fi
echo "Mihomo установлен. Отредактируйте /opt/etc/mihomo/config.yaml"
exit 0
EOF
    chmod 755 "${PKG_DIR}/CONTROL/postinst"

    cat > "${PKG_DIR}/CONTROL/prerm" << 'EOF'
#!/bin/sh
if [ -x /opt/etc/init.d/S99mihomo ]; then
    /opt/etc/init.d/S99mihomo stop
    /opt/etc/init.d/S99mihomo disable
fi
exit 0
EOF
    chmod 755 "${PKG_DIR}/CONTROL/prerm"

    cd "${PKG_DIR}"
    tar -czf control.tar.gz -C CONTROL .
    tar -czf data.tar.gz -C DATA .
    echo "2.0" > debian-binary
    IPK_NAME="mihomo_${FULL_VERSION}_${IPK_ARCH}.ipk"
    tar -czf "${IPK_NAME}" debian-binary control.tar.gz data.tar.gz

    cp "${IPK_NAME}" "${OUTPUT_DIR}/"
    cd "${WORK_DIR}/src"

    echo -e "${GREEN}Пакет для ${ARCH_NAME} готов: ${IPK_NAME}${NC}"
}

# Сборка для aarch64
build_for_arch "arm64" "aarch64-3.10" "aarch64"

# Сборка для mipsel
build_for_arch "mipsle" "mipsel-3.4" "mipsel"

# Информация для CI (создание релиза)
cat > "${OUTPUT_DIR}/BUILD_INFO" << EOF
MIHOMO_BRANCH=${BRANCH}
MIHOMO_VERSION=${FULL_VERSION}
MIHOMO_DISPLAY_VERSION=${DISPLAY_VERSION}
MIHOMO_COMMIT=${COMMIT}
MIHOMO_SOURCE=${SOURCE_REPO}
EOF

# Очистка
cd "${WORK_DIR}"
rm -rf *

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Сборка завершена!                     ${NC}"
echo -e "${GREEN}  Пакеты сохранены в: ${OUTPUT_DIR}    ${NC}"
echo -e "${GREEN}  Содержимое:${NC}"
ls -lh "${OUTPUT_DIR}"/*.ipk
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Для установки на роутере:${NC}"
echo "  scp ${OUTPUT_DIR}/mihomo_*_aarch64-3.10.ipk root@<IP_роутера>:/tmp/"
echo "  ssh root@<IP_роутера> opkg install /tmp/mihomo_*_aarch64-3.10.ipk"
echo
echo "  scp ${OUTPUT_DIR}/mihomo_*_mipsel-3.4.ipk root@<IP_роутера>:/tmp/"
echo "  ssh root@<IP_роутера> opkg install /tmp/mihomo_*_mipsel-3.4.ipk"
