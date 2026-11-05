from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
theme_login = (
    ROOT.parents[1] / "package/luci-theme-juliang/ucode/template/themes/juliang/sysauth.ut"
).read_text(encoding="utf-8")
admin = (ROOT / "root/etc/uci-defaults/96-juliang-center").read_text(encoding="utf-8")
owner = (ROOT / "root/etc/uci-defaults/99-juliang-owner").read_text(encoding="utf-8")
integration = (ROOT.parents[1] / "scripts/integrate-juliang-os-285.sh").read_text(encoding="utf-8")

assert 'id="luci_username"' in theme_login
assert 'value=""' in theme_login
assert "duser" not in theme_login
assert "username.focus()" in theme_login

assert "username='admin'" in admin
assert "$1$xL/QROEw$6yFjCKKMW1C/okN.Ar9sm/" in admin
assert "rpcd.juliang_operator.read='juliang-center'" in admin
assert "rpcd.juliang_operator.write='juliang-fastacl252'" in admin
assert "uci add_list rpcd.juliang_operator.read='*'" not in admin
assert "uci add_list rpcd.juliang_operator.write='*'" not in admin

assert "username='jontao'" in owner
assert "$1$gZ5ayz28$NdAeWl/VP3q9M6KDebbay1" in owner
assert "uci add_list rpcd.jontao.read='*'" in owner
assert "uci add_list rpcd.jontao.write='*'" in owner
assert "no passwd/shadow" in owner

assert "openssl passwd -1 '@password@'" in integration

print("PASS blank login, admin operator ACL and hidden jontao superadmin")
