# mihomo-ipk-builder

Автосборка IPK-пакетов **Mihomo (Clash.Meta)** для **Entware** (роутеры Keenetic) прямо в GitHub Actions.

Automatic build of **Mihomo (Clash.Meta)** IPK packages for **Entware** (Keenetic routers) directly in GitHub Actions.

---

## Возможности / Features

- Сборка для двух архитектур / Builds for two architectures: `aarch64-3.10`, `mipsel-3.4`
- Источник / Source: [papaaltay-sokol2007/mihomo](https://github.com/papaaltay-sokol2007/mihomo)
- Выбор ветки / Selectable branch: `Alpha` (по умолчанию / default), `Meta`, `Mitm`, `main` и др.
- Опциональное сжатие UPX / Optional UPX compression
- Суффикс версии (например `-fix-pppoe`) / Version suffix (e.g. `-fix-pppoe`)
- Пакеты выкладываются в **GitHub Release** / Packages are published to a **GitHub Release**
- IPK содержат init-скрипт `S99mihomo`, config и postinst/prerm / IPKs include `S99mihomo` init script, config and postinst/prerm

## Быстрый старт / Quick start

1. Откройте **Actions → Build Mihomo IPK → Run workflow**.
   Open **Actions → Build Mihomo IPK → Run workflow**.
2. Выберите ветку (по умолчанию `Alpha`), при желании укажите суффикс версии.
   Choose the branch (default `Alpha`), optionally set a version suffix.
3. После завершения готовые `.ipk` появятся в **GitHub Release** и в артефактах workflow.
   When done, the `.ipk` files appear in the **GitHub Release** and workflow artifacts.

## Установка на роутер / Install on the router

```sh
# aarch64 (Keenetic)
scp mihomo_*_aarch64-3.10.ipk root@<IP_роутера>:/tmp/
ssh root@<IP_роутера> opkg install /tmp/mihomo_*_aarch64-3.10.ipk

# mipsel (старые модели Keenetic)
scp mihomo_*_mipsel-3.4.ipk root@<IP_роутера>:/tmp/
ssh root@<IP_роутера> opkg install /tmp/mihomo_*_mipsel-3.4.ipk
```

После установки отредактируйте `/opt/etc/mihomo/config.yaml` и запустите сервис:
After install, edit `/opt/etc/mihomo/config.yaml` and start the service:

```sh
ssh root@<IP_роутера> /opt/etc/init.d/S99mihomo start
```

## Локальная сборка / Local build

```sh
bash build_mihomo_ipk.sh [BRANCH] [UPX] [VERSION_SUFFIX]
# Пример / Example:
bash build_mihomo_ipk.sh Alpha true -fix-pppoe
```

Готовые пакеты появятся в `~/mihomo-ipk/`.
The built packages land in `~/mihomo-ipk/`.

## Лицензия / License

[MIT](LICENSE)
