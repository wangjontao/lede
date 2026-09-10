#!/bin/bash
set -euo pipefail

PROFILE='cmcc_a10-ubootmod'
DTS='target/linux/mediatek/dts/mt7981b-cmcc-a10-ubootmod.dts'
IMAGE_MK='target/linux/mediatek/image/filogic.mk'
TARGET_MK='target/linux/mediatek/Makefile'
PLATFORM_UPGRADE='target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh'
SEED='custom/device/config.seed'
PREPARE='custom/device/prepare.sh'
FIRSTBOOT='files/usr/libexec/dulwifi-firstboot'

printf '[A10-U-BootMod] pinning MediaTek target to Linux 6.6...\n'
sed -i 's/^KERNEL_PATCHVER:=6\.12$/KERNEL_PATCHVER:=6.6/' "$TARGET_MK"
grep -q '^KERNEL_PATCHVER:=6.6$' "$TARGET_MK"
grep -q '^LINUX_VERSION-6.6 = .156$' include/kernel-6.6

printf '[A10-U-BootMod] installing FIT/UBI device image definition...\n'
if ! grep -q '^define Device/cmcc_a10-ubootmod$' "$IMAGE_MK"; then
cat >> "$IMAGE_MK" <<'EOF'

define Device/cmcc_a10-ubootmod
  DEVICE_VENDOR := CMCC
  DEVICE_MODEL := A10 (OpenWrt U-Boot layout)
  DEVICE_DTS := mt7981b-cmcc-a10-ubootmod
  DEVICE_DTS_DIR := ../dts
  DEVICE_DTS_LOADADDR := 0x43f00000
  DEVICE_PACKAGES := kmod-mt7981-firmware mt7981-wo-firmware
  IMAGE/sysupgrade.itb := append-kernel | fit gzip $$(KDIR)/image-$$(DEVICE_DTS).dtb external-with-rootfs | append-metadata
endef
TARGET_DEVICES += cmcc_a10-ubootmod
EOF
fi

grep -q '^define Device/cmcc_a10-ubootmod$' "$IMAGE_MK"
grep -q 'external-with-rootfs' "$IMAGE_MK"

printf '[A10-U-BootMod] wiring sysupgrade FIT image to the UBI fit volume...\n'
if ! grep -q 'cmcc,a10-ubootmod)' "$PLATFORM_UPGRADE"; then
python3 - "$PLATFORM_UPGRADE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
marker = '\tcase "$board" in\n'
insert = '''\tcase "$board" in
\tcmcc,a10-ubootmod)
\t\tCI_KERNPART="fit"
\t\tnand_do_upgrade "$1"
\t\t;;
'''
if marker not in s:
    raise SystemExit('platform_do_upgrade case marker not found')
s = s.replace(marker, insert, 1)
p.write_text(s)
PY
fi
grep -A3 'cmcc,a10-ubootmod)' "$PLATFORM_UPGRADE" | grep -q 'CI_KERNPART="fit"'

printf '[A10-U-BootMod] switching build seed to dedicated profile...\n'
sed -i 's/CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_a10=y/CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_a10-ubootmod=y/' "$SEED"
sed -i 's/CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_a10=y/CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_a10-ubootmod=y/' "$PREPARE"

# Keep the firmware lean in the same way as the newer jontaoNpS builds.
sed -i '/^CONFIG_PACKAGE_luci-app-wol=y$/d' "$SEED"
sed -i '/^CONFIG_PACKAGE_luci-app-ddns=y$/d' "$SEED"
sed -i '/^CONFIG_PACKAGE_luci-app-vlmcsd=y$/d' "$SEED"
sed -i '/^CONFIG_PACKAGE_luci-app-vnstat=y$/d' "$SEED"

printf '[A10-U-BootMod] validating DulWiFi/NPS defaults...\n'
grep -q "server_addr='nps.jontao.top'" "$FIRSTBOOT"
grep -q "server_port='8024'" "$FIRSTBOOT"
grep -q "ssid='DulWiFi-2.4G'" "$FIRSTBOOT"
grep -q "ssid='DulWiFi-5G'" "$FIRSTBOOT"

printf '[A10-U-BootMod] validating reconstructed DTS...\n'
grep -q 'compatible = "cmcc,a10-ubootmod", "mediatek,mt7981"' "$DTS"
grep -q 'reg = <0x0580000 0x07a80000>' "$DTS"
grep -q 'bootargs = "root=/dev/fit0 rootwait"' "$DTS"
grep -q 'volname = "fit"' "$DTS"
grep -q 'eeprom_factory_0: eeprom@0' "$DTS"
grep -q 'macaddr_factory_a: macaddr@a' "$DTS"

printf '[A10-U-BootMod] running the established jontaoNpS feed/default preparation...\n'
bash "$PREPARE"

grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_a10-ubootmod=y$' .config
printf '[A10-U-BootMod] source preparation complete.\n'
