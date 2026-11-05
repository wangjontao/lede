#!/usr/bin/env python3
from pathlib import Path

PROFILE = Path(__file__).resolve().parents[1]
controller = PROFILE / 'root/usr/lib/lua/luci/controller/juliang_upgrade.lua'
view = PROFILE / 'root/usr/lib/lua/luci/view/juliang_center/upgrade.htm'
theme_header = PROFILE.parents[1] / 'package/luci-theme-juliang/ucode/template/themes/juliang/header.ut'

assert not controller.exists(), 'Online upgrade controller must remain removed'
assert not view.exists(), 'Online upgrade page must remain removed'
assert "'admin-juliang-upgrade'" not in theme_header.read_text(encoding='utf-8')

print('JuLiang OS online upgrade feature is disabled: OK')
