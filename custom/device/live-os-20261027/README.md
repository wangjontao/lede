# JuLiang Live OS — 设备状态快照（2026-10-27）

这份目录是**运行中设备的状态导出**，用于把 2026-10-27 在设备上用 Codex 完成的改造固化进源码树。

## 来源

| 项 | 值 |
|---|---|
| 源码仓库 | `wangjontao/lede` |
| 基线分支 | `jontaoNpS-rax3000m-nand-5wifi` |
| 基线提交 | `4e170651`（与设备 `DISTRIB_REVISION=r0-4e170651` 一致） |
| 设备 | CMCC RAX3000M NAND（MT7981 / aarch64） |
| 系统 | OpenWrt 24.10.5，内核 6.12.108，`LEDE R26.05.20` |

## 与基线分支的差异（本次固化的内容）

1. **Live WiFi**：`Live-5G` / `Live-2.4G` 两个附加 SSID，桥接 `br-live`，`172.16.1.1/24`，
   DHCP 池 `172.16.1.100-249`，DNS 与网关均指向 `172.16.1.1`，关闭 DHCPv6 / RA / NDP。
2. **去掉 5 wifi 布局**：基线脚本 `custom/device/setup_tiktok_5wifi.sh` 会建 ap01–ap05，
   设备上已改为单一 Live 双频。
3. **PassWall 清理**：PassWall 1 已移除，保留 PassWall2 `26.3.5-r1`（主开关关闭）。
4. **NPS**：域名 `nps.jontao.top:8024`，`vkey` 取 WAN MAC，首启脚本 `99-enable-nps-wan-mac`。
5. **LuCI**：侧栏卡片 “JuLiang Live OS”（导出内容不含前端文件，见下）。

## 脱敏说明

本目录中以下值已替换为占位符，真实值只存在于设备上：

- `REDACTED` —— WiFi PSK、代理节点密码/UUID、NPS vkey、LuCI 登录口令、radius/uhttpd 密钥
- `REDACTED_HOST` —— 代理节点地址、NPS 服务域名
- `REDACTED_BLOB` —— 疑似节点配置的长 base64 串

共 24 处。恢复方式：设备上 `/root/config-backups/` 内的历史备份，或重新在 LuCI 里填写。

## 未包含

- LuCI 前端改动（侧栏卡片模板/JS）不在 `/etc/config` 内，需从设备 `/usr/lib/lua/luci/` 单独导出。
- `fastacl252` 的 UCI 已导出，但其节点清单在脱敏范围内。
