# mihomo（Clash.Meta）内核包（mihomo.gz）

随 PenMods 分发的 VPN 代理内核，部署到 `/userdata/PenMods/vpn/`。

## 内容

- **mihomo v1.19.29**（linux arm64，Go 静态编译，含 gvisor），来源
  [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) releases：
  `mihomo-linux-arm64-v1.19.29.gz`
- 与 mod 的 VPN 功能配合：订阅链接走 `proxy-providers` 拉取，本地 mixed 端口 7890

## 部署

- mod 启动 VPN 时若 `/userdata/PenMods/vpn/mihomo` 缺失，会自动从
  `/userdata/PenMods/vpn/mihomo.gz` 解压部署（`gzip -dc`）
- 安装器/安装脚本把 `mihomo.gz` 放到 `/userdata/PenMods/vpn/`

## 许可

mihomo 为 GPL-3.0 许可，分发时保留上游来源。
