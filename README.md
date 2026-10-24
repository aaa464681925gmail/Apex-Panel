# R-Panel

基于官方 X-Panel v26.4.25 的改版面板，面板内显示名为 R-XPANEL。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/aaa464681925gmail/R-Panel/main/install.sh)
```

要求：root 权限运行，仅支持 x86-64（amd64）架构。

安装完成后按提示设置面板用户名、密码、端口和访问路径；全新安装选 n 时会生成随机登录信息，之后可用 `x-ui` 命令的数字 10 选项查看。

## 改版功能

- **一键新建节点**：入站列表顶部下拉，一键创建 VLESS WS+TLS、VLESS TCP、VLESS REALITY、Shadowsocks、Hysteria2、Hysteria2-端口跳跃、VMess、Trojan、Socks、HTTP、WireGuard。
- **Hysteria2-端口跳跃**：单独的一项，不改原来的 Hysteria2。新建时从零创建，备注格式 Hysteria2-跳跃-端口，默认跳跃段 20000-50000（UDP），间隔 30 秒；建完弹窗里同时给单端口链接和端口段链接，不支持跳跃的客户端仍可用单端口链接。注意：跳跃要靠防火墙把端口段转发到主端口，弹窗里会给一条可直接复制的防火墙命令，跑之前跳跃不生效，单端口不受影响；删节点时防火墙规则不会自动消失，弹窗和确认框里有提醒。
- **一键删除全部入站**：入站列表顶部、一键新建旁边的红色按钮，点后先弹确认框，写清共删几个、包括模板、删了不可恢复，点取消什么都不动，点确认删除才逐个删，删完汇总删成功几个、失败几个。模板也会被删掉，删完一键克隆就没有模板了，需要重新装模板。
- **协议备注**：一键创建的节点备注自动带协议名和端口，例如 REALITY-24836、Hysteria2-34440、WS+TLS-42507，不再是通用的“新节点-端口”。
- **REALITY 伪装域名预设**：REALITY 设置里 Target 和 SNI 旁有刷新按钮，点一下按预设顺序换下一个伪装域名，Target 和 SNI 一起换，密钥、Short IDs 不动。预设共 12 个，均为非 Cloudflare CDN、且不在中国境内解析的国外大站：www.cisco.com、www.nokia.com、www.hoyoverse.com、www.lovelive-anime.jp、www.revolve.com、www.samsung.com、www.oracle.com、www.intel.com、www.adobe.com、www.dell.com、store.steampowered.com、www.nvidia.com。
- **Hysteria2 导出**：一键建完 Hysteria2 后自动弹出导出链接弹窗，可直接复制；Socks、HTTP 面板本身无可复制链接，需手动填客户端。
- **仪表盘去广告**：仪表盘 R-XPANEL 卡片里的两个 TG 按钮已去掉，版本号标签和 Pro 购买入口保留。
- **主题预设 7 套**：侧边栏主题子菜单里切，登录页也有下拉框。默认墨绿、深空蓝、曜石黑、浅色护眼、紫夜、黑金（黑底 + 金色）、极夜蓝（近黑底 + 亮蓝）。深空蓝、紫夜、黑金、极夜蓝选后强制暗色，手动切暗色开关则回到默认墨绿。
- **Tunnel 说明**：Tunnel（dokodemo）未进一键菜单，因为它需要填目标地址和端口，编假默认会转错地方，需在添加表单里手动建模板。
- **面板品牌与侧边栏**：面板显示名改为 R-XPANEL；侧边栏只去掉“实用导航”，其余主题、系统状态、入站列表、面板设置、Xray 设置、主从管理、退出登录全部保留；Pro 的闪电入口隐藏，授权校验本身未动。
- **布局**：窄屏下一键按钮文字缩短，工具栏不遮挡，备注列不折成多行。

## 注意事项

- **不要点面板里的“更新面板”按钮**，点它会覆盖回官方版，一键功能就丢了。
- Hysteria2 走 UDP（QUIC），服务器开了防火墙的话，记得放行所建 Hysteria2 端口的 UDP；端口跳跃还要放行 20000-50000 的 UDP 并跑弹窗里的转发命令。
- 本改版不索取、不校验任何授权码，Pro 授权逻辑未改动。

## 版本说明

- 基础版本固定为官方 v26.4.25，不跟随官方最新版，避免一键功能丢失。
- 最新正式版见右侧 Releases，安装脚本下载的二进制与该 Release 对应。
