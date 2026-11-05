#!/usr/bin/env python3
import argparse
import json
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "build-configs/JuLiang-OS-v2.8.5-MT7981.json"
SINGLE_TARGET_PREFIX = "CONFIG_TARGET_mediatek_filogic_DEVICE_"
MULTI_TARGET_PREFIX = "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_"
OPTIONAL_BOOTLOADER_PACKAGES = (
    "trusted-firmware-a-mt7981-emmc-ddr3",
    "trusted-firmware-a-mt7981-emmc-ddr3-1866",
    "u-boot-mt7981_cmcc_rax3000me-emmc",
    "trusted-firmware-a-mt7981-spim-nand-ddr3",
    "trusted-firmware-a-mt7981-spim-nand-ddr3-1866",
    "u-boot-mt7981_cmcc_rax3000me-nand-ddr3",
    "trusted-firmware-a-mt7981-spim-nand-ddr4",
    "u-boot-mt7981_cmcc_rax3000me-nand-ddr4",
)


def load_devices():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    devices = data["devices"]
    names = [entry["device"] for entry in devices]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate MT7981 device in build manifest")
    return devices


def replace_setting(lines, key, value):
    if value in ("y", "m", "n"):
        replacement = f"{key}={value}"
    else:
        replacement = f'{key}="{value}"'
    kept = []
    replaced = False
    for line in lines:
        if line.startswith(f"{key}="):
            if not replaced:
                kept.append(replacement)
                replaced = True
            continue
        kept.append(line)
    if not replaced:
        kept.append(replacement)
    return kept


def configure(config_path):
    devices = load_devices()
    lines = config_path.read_text(encoding="utf-8").splitlines()
    if "CONFIG_TARGET_mediatek=y" not in lines or "CONFIG_TARGET_mediatek_filogic=y" not in lines:
        raise ValueError("MT7981 build requires the MediaTek Filogic target")

    lines = [
        line
        for line in lines
        if not line.startswith(SINGLE_TARGET_PREFIX)
        and not line.startswith(MULTI_TARGET_PREFIX)
        and not line.startswith("CONFIG_TARGET_ALL_PROFILES")
        and not any(
            line.startswith(f"CONFIG_PACKAGE_{package}=")
            for package in OPTIONAL_BOOTLOADER_PACKAGES
        )
    ]
    lines = replace_setting(lines, "CONFIG_TARGET_MULTI_PROFILE", "y")
    lines = replace_setting(lines, "CONFIG_TARGET_PER_DEVICE_ROOTFS", "y")
    lines = replace_setting(lines, "CONFIG_IMAGEOPT", "y")
    lines = replace_setting(lines, "CONFIG_VERSIONOPT", "y")
    lines = replace_setting(lines, "CONFIG_VERSION_DIST", "JuLiang OS")
    lines = replace_setting(lines, "CONFIG_VERSION_MANUFACTURER", "JuLiang OS")
    lines = replace_setting(lines, "CONFIG_VERSION_PRODUCT", "JuLiang OS")
    lines = replace_setting(lines, "CONFIG_VERSION_NUMBER", "v2.8.5")
    lines = replace_setting(lines, "CONFIG_VERSION_HWREV", "MT7981")
    lines = replace_setting(lines, "CONFIG_VERSION_CODE", "MT7981-ALL")
    lines.append("")
    lines.append("# CONFIG_TARGET_ALL_PROFILES is not set")
    lines.append("# JuLiang OS v2.8.5 MT7981 target set")
    lines.extend(f"{MULTI_TARGET_PREFIX}{entry['device']}=y" for entry in devices)
    config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Configured {len(devices)} MT7981 devices")


def verify_config(config_path):
    expected = {entry["device"] for entry in load_devices()}
    selected = set()
    settings = {}
    for line in config_path.read_text(encoding="utf-8").splitlines():
        if line.startswith(MULTI_TARGET_PREFIX) and line.endswith("=y"):
            selected.add(line[len(MULTI_TARGET_PREFIX):-2])
        if line.startswith("CONFIG_") and "=" in line:
            key, _, value = line.partition("=")
            settings[key] = value.strip('"')

    missing = sorted(expected - selected)
    unexpected = sorted(selected - expected)
    if missing or unexpected:
        raise ValueError(
            f"MT7981 target mismatch: missing={missing or 'none'}, "
            f"unexpected={unexpected or 'none'}"
        )
    if settings.get("CONFIG_VERSION_HWREV") != "MT7981":
        raise ValueError("CONFIG_VERSION_HWREV must be MT7981")
    if settings.get("CONFIG_VERSION_CODE") != "MT7981-ALL":
        raise ValueError("CONFIG_VERSION_CODE must be MT7981-ALL")
    if settings.get("CONFIG_TARGET_MULTI_PROFILE") != "y":
        raise ValueError("CONFIG_TARGET_MULTI_PROFILE must be enabled")
    if settings.get("CONFIG_TARGET_PER_DEVICE_ROOTFS") != "y":
        raise ValueError("CONFIG_TARGET_PER_DEVICE_ROOTFS must be enabled")
    if settings.get("CONFIG_TARGET_ALL_PROFILES") == "y":
        raise ValueError("CONFIG_TARGET_ALL_PROFILES must be disabled for an MT7981-only build")
    if settings.get("CONFIG_IMAGEOPT") != "y" or settings.get("CONFIG_VERSIONOPT") != "y":
        raise ValueError("IMAGEOPT and VERSIONOPT must be enabled")
    expected_version = {
        "CONFIG_VERSION_DIST": "JuLiang OS",
        "CONFIG_VERSION_MANUFACTURER": "JuLiang OS",
        "CONFIG_VERSION_PRODUCT": "JuLiang OS",
        "CONFIG_VERSION_NUMBER": "v2.8.5",
        "CONFIG_VERSION_HWREV": "MT7981",
        "CONFIG_VERSION_CODE": "MT7981-ALL",
    }
    for key, value in expected_version.items():
        if settings.get(key) != value:
            raise ValueError(f"{key} must be {value}")
    print(f"Verified {len(expected)} MT7981 targets in {config_path}")


def image_name(device):
    return f"juliang-os-v2.8.5-mediatek-filogic-{device}-squashfs-sysupgrade.bin"


def collect(source, destination):
    devices = load_devices()
    destination.mkdir(parents=True, exist_ok=True)
    inventory = []
    for entry in devices:
        name = image_name(entry["device"])
        image = source / name
        if not image.is_file():
            raise FileNotFoundError(image)
        shutil.copy2(image, destination / name)
        manifest = source / f"openwrt-mediatek-filogic-{entry['device']}.manifest"
        if manifest.is_file():
            shutil.copy2(manifest, destination / manifest.name)
        inventory.append(f"{entry['device']}\t{entry['label']}\t{name}")

    for name in ("profiles.json", "config.buildinfo", "feeds.buildinfo", "version.buildinfo"):
        path = source / name
        if path.is_file():
            shutil.copy2(path, destination / name)
    (destination / "INVENTORY.txt").write_text(
        "device\tlabel\timage\n" + "\n".join(inventory) + "\n",
        encoding="utf-8",
    )
    print(f"Collected {len(devices)} MT7981 firmware images")


def verify_artifacts(source):
    devices = load_devices()
    missing = [image_name(entry["device"]) for entry in devices if not (source / image_name(entry["device"])).is_file()]
    if missing:
        raise FileNotFoundError("Missing MT7981 images: " + ", ".join(missing))
    print(f"Verified {len(devices)} MT7981 firmware images in {source}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("configure", "verify-config", "collect", "verify-artifacts"))
    parser.add_argument("path", type=Path)
    parser.add_argument("destination", type=Path, nargs="?")
    args = parser.parse_args()

    try:
        if args.command == "configure":
            configure(args.path)
        elif args.command == "verify-config":
            verify_config(args.path)
        elif args.command == "collect":
            if args.destination is None:
                parser.error("collect requires source and destination paths")
            collect(args.path, args.destination)
        else:
            verify_artifacts(args.path)
    except (FileNotFoundError, KeyError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
