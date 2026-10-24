# R-Panel

基于官方 X-Panel v26.4.25 的改版面板，面板内显示名为 R-XPANEL。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/aaa464681925gmail/R-Panel/main/install.sh)
```

要求：root 权限运行，仅支持 x86-64（amd64）架构。

安装完成后按提示设置面板用户名、密码、端口和访问路径；全新安装选 n 时会生成随机登录信息，之后可用 `x-ui` 命令的数字 10 选项查看。

## 改版功能

- **一键新建节点**：入站列表顶部下拉，一键创建 VLESS WS+TLS、VLESS TCP、VLESS REALITY、Shadowsocks、Hysteria2、VMess、Trojan、Socks、HTTP、WireGuard。
- **协议备注**：一键创建的节点备注自动带协议名和端口，例如 REALITY-24836、Hysteria2-34440、WS+TLS-42507，不再是通用的“新节点-端口”。
- **REALITY 伪装域名预设**：REALITY 设置里 Target 和 SNI 旁有刷新按钮，点一下按预设顺序换下一个伪装域名，Target 和 SNI 一起换，密钥、Short IDs 不动。预设均为非 Cloudflare CDN 的国外大站。
- **Hysteria2 导出**：一键建完 Hysteria2 后自动弹出导出链接弹窗，可直接复制；Socks、HTTP 面板本身无可复制链接，需手动填客户端。
- **Tunnel 说明**：Tunnel（dokodemo）未进一键菜单，因为它需要填目标地址和端口，编假默认会转错地方，需在添加表单里手动建模板。
- **面板品牌与侧边栏**：面板显示名改为 R-XPANEL；侧边栏只去掉“实用导航”，其余主题、系统状态、入站列表、面板设置、Xray 设置、主从管理、退出登录全部保留；Pro 的闪电入口隐藏，授权校验本身未动。
- **布局**：窄屏下一键按钮文字缩短，工具栏不遮挡，备注列不折成多行。

## 注意事项

- **不要点面板里的“更新面板”按钮**，点它会覆盖回官方版，一键功能就丢了。
- Hysteria2 走 UDP（QUIC），服务器开了防火墙的话，记得放行所建 Hysteria2 端口的 UDP。
- 本改版不索取、不校验任何授权码，Pro 授权逻辑未改动。

## 版本说明

- 基础版本固定为官方 v26.4.25，不跟随官方最新版，避免一键功能丢失。
- 最新正式版见右侧 Releases，安装脚本下载的二进制与该 Release 对应。
