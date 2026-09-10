# CMCC A10 U-BootMod firmware reconstruction notes

This target was reconstructed against a verified booting `ImmortalWrt 24.10.6` FIT sysupgrade image supplied by the device owner.

## Verified FIT image

- Platform: MediaTek MT7981 / Filogic
- Model: `CMCC A10 (OpenWrt U-Boot layout)`
- Compatible: `cmcc,a10-ubootmod`, `mediatek,mt7981`
- Verified sample kernel: Linux 6.6.133
- This LEDE branch builds against its maintained Linux 6.6 line (currently 6.6.156)
- Sysupgrade format: external-data FIT `.itb`
- FIT rootfs: squashfs/xz
- Boot arguments: `root=/dev/fit0 rootwait`
- FIT UBI volume name: `fit`

## RAM / storage

- RAM: 256 MiB (`0x40000000 + 0x10000000`)
- Flash: 128 MiB SPI-NAND

| Partition | Offset | Size | End |
|---|---:|---:|---:|
| BL2 | `0x0000000` | `0x0100000` (1 MiB) | `0x0100000` |
| u-boot-env | `0x0100000` | `0x0080000` (512 KiB) | `0x0180000` |
| Factory | `0x0180000` | `0x0200000` (2 MiB) | `0x0380000` |
| FIP | `0x0380000` | `0x0200000` (2 MiB) | `0x0580000` |
| ubi | `0x0580000` | `0x07a80000` (122.5 MiB) | `0x08000000` |

The UBI partition therefore ends exactly at the end of the 128 MiB NAND. The legacy LEDE A10 layout with separate `backup`, `zrsave`, and `config2` partitions must **not** be used for this U-BootMod target.

## Factory / NVMEM

Factory partition data is preserved and consumed directly by drivers:

- Wi-Fi EEPROM: Factory `0x0000`, length `0x1000`
- 5 GHz / band1 Wi-Fi MAC base: Factory `0x000a`, length 6
- WAN MAC base: Factory `0x0024`, length 6
- GMAC0 MAC base: Factory `0x002a`, length 6

Never erase or regenerate the Factory partition when flashing this target.

## Wireless

- Integrated MT7981 Wi-Fi 6 radio (DBDC 2.4 GHz + 5 GHz)
- No external PCIe Wi-Fi radio is required
- Calibration is read from Factory EEPROM rather than hard-coded
- Default customized SSIDs are applied at first boot by the existing DulWiFi script:
  - `DulWiFi-2.4G`
  - `DulWiFi-5G`
  - password: `password`

## Ethernet

- MT7531 switch at MDIO address 31
- GMAC0: `2500base-x`, fixed 2.5 Gbit/s link to switch CPU port
- User-facing ports: LAN1, LAN2, LAN3, WAN
- Switch reset GPIO 39, interrupt GPIO 38

## GPIO / LEDs

- Reset button: GPIO 1 active-low
- WPS button: GPIO 0 active-low
- Blue status LED: GPIO 9 active-low
- Green status LED: GPIO 10 active-low
- Red status LED: GPIO 11 active-low

## Build profile

Profile: `cmcc_a10-ubootmod`

Image recipe:

```make
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
```

The branch preparation script injects this profile without changing the legacy `cmcc_a10` target.
