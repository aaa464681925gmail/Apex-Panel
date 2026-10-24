# Apex Panel

基于官方 X-Panel v26.4.25 的改版面板，面板内显示名为 Apex Panel。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/aaa464681925gmail/Apex-Panel/main/install.sh)
```

安装后按提示操作。已装旧版要升级时，在安装提示里选 n，保留旧的登录、端口、路径和入站，不要点面板里的“更新面板”按钮，否则会被覆盖回官方版。

## v11 主要内容

- 一键新建节点：一键克隆模板（端口、UUID/密码/密钥全新，模板本身不动），无模板时按面板自带形状从零新建
- 协议：一键新建含 VLESS TCP、VLESS WS、VLESS TCP+REALITY、Shadowsocks、Hysteria2、Hysteria2-端口跳跃，以及新增的 VLESS XHTTP、VLESS XHTTP+TLS、VLESS XHTTP+REALITY
- REALITY 伪装域名预设 12 个，可循环切换
- Hysteria2 导出链接弹窗，含复制按钮；端口跳跃为防火墙 DNAT 方案，单端口链接仍可用
- 入站列表删除全部入站已移到下拉菜单，并有二次确认，避免误触
- 原生克隆入站会保留客户端 Flow（REALITY 克隆不再丢 xtls-rprx-vision）
- 主题预设 16 套：默认墨绿、曜石黑、浅色护眼、紫夜、黑金、极夜蓝，以及新增的烈焰红、樱花粉、玫瑰红、翠绿、柠檬绿、咖啡棕、烟灰、石板灰蓝、翡翠绿、藏青；深空蓝已去掉
- 仪表盘跟随主题，登录不再弹欢迎弹窗
- 导航页介绍内容已全部去掉，侧边栏只有主题、系统状态、入站列表、面板设置、Xray 设置、主从管理、退出登录

## 注意

- Hysteria2 端口跳跃需要自己放行 UDP 端口段并做 DNAT，面板里有命令提示
- 本仓库保留 v4、v9 Release，v11 为最新版
