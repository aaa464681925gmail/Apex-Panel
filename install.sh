#!/bin/bash

# ==========================================================
# Apex Panel v47 安装脚本（一键新建节点版）
# 基础：官方 X-Panel install.sh 的免费版流程（xeefei/x-panel）
# 改动说明（只改安装来源与版本锁定）：
# 1. 面板版本固定为 v26.4.25，不再去 GitHub API 取最新版。
# 取最新版会装成官方 26.9.13，改版的一键功能就丢了。
# 2. 架构只允许 amd64：改版二进制只有 x86-64 构建，
# arm64/armv7 等架构会明确报错退出，不会装错二进制。
# 3. 先下载官方 v26.4.25 包和改版二进制，两个都校验通过
# （非空、改版二进制内含“一键新建节点”和 getNewHyCert）
# 之后，才停服务、删旧目录、解压、覆盖二进制。
# 任一下载或校验失败都会在动旧安装之前退出，旧面板不受影响。
# 4. 管理脚本 x-ui.sh 改用本仓库维护的版本：以 v26.4.25 tag 原始文件为
# 底本（与二进制版本一致），已去掉菜单推广段、显示名改为 apex-panel、
# 新增菜单 26「TCP 调优」。安装时 /usr/bin/x-ui 与 /usr/local/x-ui/x-ui.sh
# 两份都用它，保证内容一致。
# 7. 随包内置 tcpfit v0.5.9（本仓库 tcpfit.sh）：下载后按固定 SHA256
# 校验，装到 /usr/local/x-ui/tcpfit.sh，菜单 26 离线调用，默认关闭其
# 匿名运行计数。tcpfit 版本跟随本仓库发版更新，机器上不各自自更新。
# 改版二进制来源不变，仍为本仓库 Release v47。
# 8. v41 起随包内置 EZrealm v1.1.1（本仓库 realm.sh）：下载后按固定 SHA256
# 校验，装到 /usr/local/x-ui/realm.sh，菜单 27「Realm 中转」调用，并带
# --no-update 跳过它自带的更新检查（同 tcpfit，版本跟随发版）。它管理的
# 仍是 /root/realm/config.toml 与 realm.service，已装过 Realm 的机器原有
# 转发规则不受影响，安装过程不碰 /root/realm。
# 9. v42 起加 glibc 预检：v46 及以前的改版二进制要求 glibc >= 2.34
# （Debian 11 自带 2.31 装不上，v41 曾因此让 breayun4837 面板起不来）。
# 本检查在下载校验之后、停服务删旧目录之前执行：本机 glibc 低于门槛，
# 或 ldd 报告改版二进制有缺失依赖，直接退出，旧面板原样保留。
# v47 起二进制按 glibc 2.31 构建，门槛降为 2.31，Debian 11 可直接装。
# 10. v42 起面板内置「超额限速」：客户端的独立限速（恒定限速，KB/s）与
# 超额限速（每日 20G 或总流量用超后限速到设定值，不断线）二选一；没开
# 超额限速的客户端每日超额会被实时停用、次日自动恢复。限速由随包的
# client-guard 守护进程执行（Release 里的 guard-bundle.tar.gz，含
# client-guard、client-guard-aux、disable-watchdog 三个 systemd 服务），
# 安装时一并装好并给 Xray 模板补上 RoutingService。已存在的
# /etc/client-guard/config.json 与 /opt/client-guard/aux.json 不覆盖。
# 11. v43 起修正「耗尽」分类：以前面板把所有被停用的客户端都算作耗尽
#（手动关闭、到期、每日超额停用的全混在一起），连“删除流量耗尽的客户
# 端”也会误删这些人。v43 起前端名单与后端删除都只认总流量真跑满
#（total > 0 且已用 >= total），其余停用一律归“关闭”。
# 12. v44 起更名：「即将耗尽」改为「超量限速」。trafficDiff 默认为 0，
# 该分类实际在已用量超过总额时才亮起，且触发后执行的是 client-guard
# 的超量限速而非断开连接，旧名误导。面板分类名、电报机器人按钮与
# 通知文案三处已改，key（depletingSoon / depleteSoon）保持不变。
# 13. v45 起 client-guard 增加用户归属对账：每 10 秒核对 live xray，
# DB 里正常的客户端若被 API 弄丢会自动加回（修 SS 客户端未超量却断连的 bug）。
# 14. v46 起修复缺失的客户端流量行：以前客户端若未经面板流程写入
# 设置（如批量脚本添加），client_traffics 里永远没有它的行——不计
# 流量、每日自动重置不生效、面板显示 0/∞、与入站流量对不上账。
# v46 在面板每次启动时执行迁移（此前 MigrateDB 只在 migrate 子命令
# 与导入数据库时运行，正常启动从不执行），逐入站核对并按客户端自身
# 设置补建缺失行，幂等；升级后开机即自愈。
# 15. v47 起三处修复/新增：(a)「更多信息」弹窗打不开——同一客户端名
# 存在于多个入站时 client_traffics 只有一行、挂在其中一个入站下，
# 另一入站列表里该客户端没有流量统计，弹窗额度标签对空统计未做
# 防护会崩溃；v47 已加空值防护。(b) 放宽邮箱唯一校验：同一客户端名
# 可在多个入站添加/改名，共用同一行流量统计，改名撞行时计数合并。
# (c) 客户端列表长按拖动排序（约 0.25 秒触发，专用接口落库，只换
# settings 顺序，不碰流量行、不重启 Xray）。另：v47 二进制改为按
# glibc 2.31 目标构建（zig cc -target x86_64-linux-gnu.2.31），
# Debian 11 起通用，第 9 条的 glibc 预检门槛随之由 2.34 降为 2.31。
# 5. 保留官方 config_after_install() 的设账号流程：
# 选 y 依次设用户名、密码、面板端口、访问路径；
# 选 n 且全新安装时打印随机账号密码路径，之后可用 x-ui
# 菜单 10 查看；选 n 且是升级时保留旧设置。
# 6. Hysteria2 走 UDP（QUIC），与 TCP 入站不同：
# 若服务器开了防火墙，记得放行所建 Hysteria2 端口的 UDP。
# 用法（与官方命令同格式，一行）：
# bash <(curl -Ls https://raw.githubusercontent.com/aaa464681925gmail/Apex-Panel/main/install.sh)
# 注意：改版二进制放在本仓库的 Release v47 里，不会像临时文件链接那样过期。
# ==========================================================

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用 root 权限运行此脚本\n" && exit 1

MOD_VERSION="v26.4.25"
OFFICIAL_TAR_URL="https://github.com/xeefei/x-panel/releases/download/${MOD_VERSION}/x-ui-linux-amd64.tar.gz"
MOD_BIN_URL="https://github.com/aaa464681925gmail/Apex-Panel/releases/download/v47/x-ui"
MOD_BIN_SHA256="05b44e528efd492d30acc637e4f595950128defbb6e60b878bc3a653c00c8f5a"
XUI_SH_URL="https://raw.githubusercontent.com/aaa464681925gmail/Apex-Panel/main/x-ui.sh"
TCPFIT_URL="https://raw.githubusercontent.com/aaa464681925gmail/Apex-Panel/main/tcpfit.sh"
TCPFIT_SHA256="8331cc40950229a3280ce32406330a85b1a3d21ba398a4db3dc7e25c39783741"
REALM_URL="https://raw.githubusercontent.com/aaa464681925gmail/Apex-Panel/main/realm.sh"
REALM_SHA256="1a165435d9c38e7c1bac91ca85d59e8485c31223c300ff1cd9e7f5af4069464a"
GUARD_URL="https://github.com/aaa464681925gmail/Apex-Panel/releases/download/v47/guard-bundle.tar.gz"
GUARD_SHA256="5af1aeaf953a647b30d428ce6aaaa07898f4fd7f274aeb22eda505265c1be75c"

# ----------------------------------------------------------
# 检查操作系统与架构（amd64 专属）
# ----------------------------------------------------------
if [[ -f /etc/os-release ]]; then
source /etc/os-release
release=$ID
elif [[ -f /usr/lib/os-release ]]; then
source /usr/lib/os-release
release=$ID
else
echo ""
echo -e "${red}检查服务器操作系统失败，请联系作者!${plain}" >&2
exit 1
fi
echo ""
echo -e "${green}---------->>>>>目前服务器的操作系统为: $release${plain}"

arch() {
case "$(uname -m)" in
x86_64 | x64 | amd64) echo 'amd64';;
*) echo -e "${red}不支持的CPU架构! 改版二进制只有 x86-64 (amd64) 构建，arm64 等架构请勿安装。${plain}" >&2 && exit 1;;
esac
}

echo ""
echo -e "${yellow}---------->>>>>当前系统的架构为: $(arch)${plain}"
echo ""
echo -e "${green}---------->>>>>改版面板版本固定为: ${MOD_VERSION}（不取最新版，避免丢掉一键功能）${plain}"
echo ""

os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d. -f1)

if [[ "${release}" == "arch" ]]; then
echo "您的操作系统是 ArchLinux"
elif [[ "${release}" == "manjaro" ]]; then
echo "您的操作系统是 Manjaro"
elif [[ "${release}" == "armbian" ]]; then
echo "您的操作系统是 Armbian"
elif [[ "${release}" == "alpine" ]]; then
echo "您的操作系统是 Alpine Linux"
elif [[ "${release}" == "opensuse-tumbleweed" ]]; then
echo "您的操作系统是 OpenSUSE Tumbleweed"
elif [[ "${release}" == "centos" ]]; then
if [[ ${os_version} -lt 8 ]]; then
echo -e "${red} 请使用 CentOS 8 或更高版本 ${plain}\n" && exit 1
fi
elif [[ "${release}" == "ubuntu" ]]; then
if [[ ${os_version} -lt 20 ]]; then
echo -e "${red} 请使用 Ubuntu 20 或更高版本!${plain}\n" && exit 1
fi
elif [[ "${release}" == "fedora" ]]; then
if [[ ${os_version} -lt 36 ]]; then
echo -e "${red} 请使用 Fedora 36 或更高版本!${plain}\n" && exit 1
fi
elif [[ "${release}" == "debian" ]]; then
if [[ ${os_version} -lt 11 ]]; then
echo -e "${red} 请使用 Debian 11 或更高版本 ${plain}\n" && exit 1
fi
elif [[ "${release}" == "almalinux" ]]; then
if [[ ${os_version} -lt 9 ]]; then
echo -e "${red} 请使用 AlmaLinux 9 或更高版本 ${plain}\n" && exit 1
fi
elif [[ "${release}" == "rocky" ]]; then
if [[ ${os_version} -lt 9 ]]; then
echo -e "${red} 请使用 RockyLinux 9 或更高版本 ${plain}\n" && exit 1
fi
elif [[ "${release}" == "oracle" ]]; then
if [[ ${os_version} -lt 8 ]]; then
echo -e "${red} 请使用 Oracle Linux 8 或更高版本 ${plain}\n" && exit 1
fi
else
echo -e "${red}此脚本不支持您的操作系统。${plain}\n"
echo "请确保您使用的是以下受支持的操作系统之一："
echo "- Ubuntu 20.04+"
echo "- Debian 11+"
echo "- CentOS 8+"
echo "- Fedora 36+"
echo "- Arch Linux"
echo "- Manjaro"
echo "- Armbian"
echo "- Alpine Linux"
echo "- AlmaLinux 9+"
echo "- Rocky Linux 9+"
echo "- Oracle Linux 8+"
echo "- OpenSUSE Tumbleweed"
exit 1
fi

install_base() {
case "${release}" in
ubuntu | debian | armbian)
apt-get update && apt-get install -y -q wget curl sudo tar tzdata
;;
centos | rhel | almalinux | rocky | ol)
yum -y --exclude=kernel* update && yum install -y -q wget curl sudo tar tzdata
;;
fedora | amzn | virtuozzo)
dnf -y --exclude=kernel* update && dnf install -y -q wget curl sudo tar tzdata
;;
arch | manjaro | parch)
pacman -Sy && pacman -S --noconfirm wget curl sudo tar tzdata
;;
alpine)
apk update && apk add --no-cache wget curl sudo tar tzdata
;;
opensuse-tumbleweed)
zypper refresh && zypper -q install -y wget curl sudo tar timezone
;;
*)
apt-get update && apt-get install -y -q wget curl sudo tar tzdata
;;
esac
}

gen_random_string() {
local length="$1"
local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
echo "$random_string"
}

# 官方原样：安装/更新后提示修改面板设置
config_after_install() {
echo -e "${yellow}安装/更新完成！ 为了您的面板安全，建议修改面板设置 ${plain}"
echo ""
read -p "$(echo -e "${green}想继续修改吗？${red}选择“n”以保留旧设置${plain} [y/n]？--->>请输入：")" config_confirm
if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
read -p "请设置您的用户名: " config_account
echo -e "${yellow}您的用户名将是: ${config_account}${plain}"
read -p "请设置您的密码: " config_password
echo -e "${yellow}您的密码将是: ${config_password}${plain}"
read -p "请设置面板端口: " config_port
echo -e "${yellow}您的面板端口号为: ${config_port}${plain}"
read -p "请设置面板登录访问路径: " config_webBasePath
echo -e "${yellow}您的面板访问路径为: ${config_webBasePath}${plain}"
echo -e "${yellow}正在初始化，请稍候...${plain}"
/usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
echo -e "${yellow}用户名和密码设置成功!${plain}"
/usr/local/x-ui/x-ui setting -port ${config_port}
echo -e "${yellow}面板端口号设置成功!${plain}"
/usr/local/x-ui/x-ui setting -webBasePath ${config_webBasePath}
echo -e "${yellow}面板登录访问路径设置成功!${plain}"
echo ""
else
echo ""
sleep 1
echo -e "${red}--------------->>>>Cancel...--------------->>>>>>>取消修改...${plain}"
echo ""
if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
local usernameTemp=$(head -c 10 /dev/urandom | base64)
local passwordTemp=$(head -c 10 /dev/urandom | base64)
local webBasePathTemp=$(gen_random_string 15)
/usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp} -webBasePath ${webBasePathTemp}
echo ""
echo -e "${yellow}检测到为全新安装，出于安全考虑将生成随机登录信息:${plain}"
echo -e "###############################################"
echo -e "${green}用户名: ${usernameTemp}${plain}"
echo -e "${green}密 码: ${passwordTemp}${plain}"
echo -e "${green}访问路径: ${webBasePathTemp}${plain}"
echo -e "###############################################"
echo -e "${green}如果您忘记了登录信息，可以在安装后通过 x-ui 命令然后输入${red}数字 10 选项${green}进行查看${plain}"
else
echo -e "${green}此次操作属于版本升级，保留之前旧设置项，登录方式保持不变${plain}"
echo ""
echo -e "${green}如果您忘记了登录信息，您可以通过 x-ui 命令然后输入${red}数字 10 选项${green}进行查看${plain}"
echo ""
echo ""
fi
fi
sleep 1
echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
/usr/local/x-ui/x-ui migrate
}

ssh_forwarding() {
v4=$(curl -s4m8 http://ip.sb -k)
v6=$(curl -s6m8 http://ip.sb -k)
local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath（访问路径）:.+' | awk '{print $2}')
local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port（端口号）:.+' | awk '{print $2}')
local existing_cert=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'cert:.+' | awk '{print $2}')
local existing_key=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'key:.+' | awk '{print $2}')

if [[ -n "$existing_cert" && -n "$existing_key" ]]; then
echo -e "${green}面板已安装证书采用SSL保护${plain}"
echo ""
local existing_cert=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'cert:.+' | awk '{print $2}')
domain=$(basename "$(dirname "$existing_cert")")
echo -e "${green}登录访问面板URL: https://${domain}:${existing_port}${green}${existing_webBasePath}${plain}"
fi
echo ""
if [[ -z "$existing_cert" && -z "$existing_key" ]]; then
echo -e "${red}警告：未找到证书和密钥，面板不安全！${plain}"
echo ""
echo -e "${green}------->>>>请按照下述方法设置〔ssh转发〕<<<<-------${plain}"
echo ""

if [[ -z $v4 ]]; then
echo -e "${green}1、本地电脑客户端转发命令：${plain} ${blue}ssh -L [::]:15208:127.0.0.1:${existing_port}${blue} root@[$v6]${plain}"
echo ""
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}[::1]:15208${existing_webBasePath}${plain} ${green}进入〔apex-panel面板〕登录界面"
echo ""
elif [[ -n $v4 && -n $v6 ]]; then
echo -e "${green}1、本地电脑客户端转发命令：${plain} ${blue}ssh -L 15208:127.0.0.1:${existing_port}${blue} root@$v4${plain} ${yellow}或者 ${blue}ssh -L [::]:15208:127.0.0.1:${existing_port}${blue} root@[$v6]${plain}"
echo ""
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}127.0.0.1:15208${existing_webBasePath}${plain} ${yellow}或者${plain} ${blue}[::1]:15208${existing_webBasePath}${plain} ${green}进入〔apex-panel面板〕登录界面"
echo ""
else
echo -e "${green}1、本地电脑客户端转发命令：${plain} ${blue}ssh -L 15208:127.0.0.1:${existing_port}${blue} root@$v4${plain}"
echo ""
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}127.0.0.1:15208${existing_webBasePath}${plain} ${green}进入〔apex-panel面板〕登录界面"
echo ""
fi
echo -e "${red}注意：若不使用〔ssh转发〕请为apex-panel面板配置安装证书再行登录管理后台${plain}"
fi
}

install_modified() {
cd /usr/local/ || exit 1

# ---- 第一步：先下载，全部校验通过之后才动旧安装 ----
echo ""
echo -e "${green}--------->>下载官方 X-Panel ${MOD_VERSION} 基础包...${plain}"
wget -N --no-check-certificate -O /usr/local/x-ui-linux-amd64.tar.gz ${OFFICIAL_TAR_URL} || {
echo -e "${red}下载官方基础包失败, 请检查服务器是否可以连接至 GitHub？ ${plain}"
exit 1
}
if [[ ! -s /usr/local/x-ui-linux-amd64.tar.gz ]]; then
echo -e "${red}官方基础包为空，退出安装，旧面板未动。${plain}"
exit 1
fi

echo -e "${green}--------->>下载改版面板二进制（一键新建节点版）...${plain}"
curl -fsSL ${MOD_BIN_URL} -o /tmp/x-ui.modified || {
echo -e "${red}下载改版二进制失败（链接可能已过期），退出安装，旧面板未动。${plain}"
exit 1
}
if [[ ! -s /tmp/x-ui.modified ]]; then
echo -e "${red}改版二进制为空，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ "$(sha256sum /tmp/x-ui.modified | awk '{print $1}')" != "${MOD_BIN_SHA256}" ]]; then
echo -e "${red}改版二进制 SHA256 校验不通过（下载到的不是 Release v47 的正式构建，可能 CDN 缓存未刷新），退出安装，旧面板未动。稍后再试。${plain}"
exit 1
fi
if [[ $(grep -a -c "一键新建节点" /tmp/x-ui.modified) -ne 1 ]]; then
echo -e "${red}改版二进制校验失败：内含“一键新建节点”计数不是 1，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "getNewHyCert" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少 Hysteria2 证书接口，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "Apex Panel" /tmp/x-ui.modified) -ne 6 ]]; then
echo -e "${red}改版二进制校验失败：Apex Panel 计数不是 6，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "cycleRealityDomain" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少 REALITY 伪装域名刷新，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "showQuickAddLink" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少建完自动弹出链接，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "deleteAllInbounds" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少一键删除全部入站，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "black-gold" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少黑金主题预设，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "night-blue" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少极夜蓝主题预设，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -a -c "hysteria2-hop" /tmp/x-ui.modified) -lt 1 ]]; then
echo -e "${red}改版二进制校验失败：缺少 Hysteria2 端口跳跃，退出安装，旧面板未动。${plain}"
exit 1
fi
chmod +x /tmp/x-ui.modified

# ---- glibc 预检（v42）：不兼容的机器在这里退出，旧面板未动 ----
glibc_version=$(ldd --version 2>/dev/null | head -1 | grep -Eo '[0-9]+\.[0-9]+' | head -1)
if [[ -n "${glibc_version}" ]]; then
if [[ "$(printf '%s\n%s\n' "2.31" "${glibc_version}" | sort -V | head -1)" != "2.31" ]]; then
echo -e "${red}本机 glibc 为 ${glibc_version}，低于改版二进制要求的 2.31，退出安装，旧面板未动。${plain}"
exit 1
fi
fi
if ldd /tmp/x-ui.modified 2>/dev/null | grep -q "not found"; then
echo -e "${red}改版二进制依赖缺失（ldd 报告 not found），退出安装，旧面板未动。${plain}"
exit 1
fi
echo -e "${green}--------->>两个文件都校验通过，开始安装...${plain}"

wget -O /usr/bin/x-ui-temp ${XUI_SH_URL} || {
echo -e "${red}下载管理脚本 x-ui.sh（${MOD_VERSION} tag）失败，退出安装，旧面板未动。${plain}"
exit 1
}
if [[ ! -s /usr/bin/x-ui-temp ]]; then
echo -e "${red}管理脚本为空，退出安装，旧面板未动。${plain}"
exit 1
fi

if [[ $(grep -c "TCP 调优" /usr/bin/x-ui-temp) -lt 1 || $(grep -c "Realm 中转" /usr/bin/x-ui-temp) -lt 1 || $(grep -c "apex-panel" /usr/bin/x-ui-temp) -lt 1 || $(grep -c "aff.php" /usr/bin/x-ui-temp) -ne 0 ]]; then
echo -e "${red}管理脚本校验失败：不是本仓库的 apex-panel 版（缺 TCP 调优菜单、显示名不对或仍带推广），退出安装，旧面板未动。${plain}"
exit 1
fi

echo -e "${green}--------->>下载内置 tcpfit v0.5.9...${plain}"
curl -fsSL ${TCPFIT_URL} -o /tmp/tcpfit.sh || {
echo -e "${red}下载 tcpfit 失败，退出安装，旧面板未动。${plain}"
exit 1
}
if [[ ! -s /tmp/tcpfit.sh ]]; then
echo -e "${red}tcpfit 文件为空，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ "$(sha256sum /tmp/tcpfit.sh | awk '{print $1}')" != "${TCPFIT_SHA256}" ]]; then
echo -e "${red}tcpfit SHA256 校验不通过，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -c 'VERSION="0.5.9"' /tmp/tcpfit.sh) -ne 1 ]]; then
echo -e "${red}tcpfit 版本校验失败：不是 v0.5.9，退出安装，旧面板未动。${plain}"
exit 1
fi

echo -e "${green}--------->>下载内置 EZrealm v1.1.1...${plain}"
curl -fsSL ${REALM_URL} -o /tmp/realm.sh || {
echo -e "${red}下载 EZrealm 失败，退出安装，旧面板未动。${plain}"
exit 1
}
if [[ ! -s /tmp/realm.sh ]]; then
echo -e "${red}EZrealm 文件为空，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ "$(sha256sum /tmp/realm.sh | awk '{print $1}')" != "${REALM_SHA256}" ]]; then
echo -e "${red}EZrealm SHA256 校验不通过，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ $(grep -c 'CURRENT_VERSION="1.1.1"' /tmp/realm.sh) -ne 1 ]]; then
echo -e "${red}EZrealm 版本校验失败：不是 v1.1.1，退出安装，旧面板未动。${plain}"
exit 1
fi

echo -e "${green}--------->>下载内置 client-guard 守护包...${plain}"
curl -fsSL ${GUARD_URL} -o /tmp/guard-bundle.tar.gz || {
echo -e "${red}下载 client-guard 守护包失败，退出安装，旧面板未动。${plain}"
exit 1
}
if [[ ! -s /tmp/guard-bundle.tar.gz ]]; then
echo -e "${red}client-guard 守护包为空，退出安装，旧面板未动。${plain}"
exit 1
fi
if [[ "$(sha256sum /tmp/guard-bundle.tar.gz | awk '{print $1}')" != "${GUARD_SHA256}" ]]; then
echo -e "${red}client-guard 守护包 SHA256 校验不通过，退出安装，旧面板未动。${plain}"
exit 1
fi


# ---- 第二步：停服务、删旧目录、解压 ----
if [[ -e /usr/local/x-ui/ ]]; then
systemctl stop x-ui
rm /usr/local/x-ui/ -rf
fi

sleep 3
echo -e "${green}------->>>>>>>>>>>检查并保存安装目录${plain}"
echo ""
tar zxvf x-ui-linux-amd64.tar.gz
rm x-ui-linux-amd64.tar.gz -f

cd x-ui || exit 1
# 解压目录里的管理脚本也换成本仓库版本，与 /usr/bin/x-ui 保持一致
cp -f /usr/bin/x-ui-temp ./x-ui.sh
# 内置 tcpfit 放到面板目录，菜单 26 从这里调用
cp -f /tmp/tcpfit.sh ./tcpfit.sh
rm -f /tmp/tcpfit.sh
# 内置 EZrealm 放到面板目录，菜单 27 从这里调用（不碰 /root/realm 里已有的配置）
cp -f /tmp/realm.sh ./realm.sh
rm -f /tmp/realm.sh
# ---- 第三步：用改版二进制覆盖官方二进制 ----
cp -f /tmp/x-ui.modified ./x-ui
rm -f /tmp/x-ui.modified
chmod +x x-ui
chmod +x x-ui.sh
chmod +x tcpfit.sh
chmod +x realm.sh
chmod +x x-ui bin/xray-linux-amd64

mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
chmod +x /usr/bin/x-ui
sleep 2
echo -e "${green}------->>>>>>>>>>>保存成功（已换成改版二进制）${plain}"
sleep 2
echo ""
config_after_install
ssh_forwarding

cp -f x-ui.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui
systemctl stop warp-go >/dev/null 2>&1
wg-quick down wgcf >/dev/null 2>&1

# ---- v42: 安装 client-guard 限速守护（超额限速/独立限速的执行端） ----
echo -e "${green}--------->>安装 client-guard 限速守护服务...${plain}"
if command -v python3 >/dev/null 2>&1; then
systemctl stop x-ui
mkdir -p /tmp/guard-bundle && tar xzf /tmp/guard-bundle.tar.gz -C /tmp/guard-bundle
cp -f /tmp/guard-bundle/usr/local/bin/client-guard.py /usr/local/bin/client-guard.py
cp -f /tmp/guard-bundle/usr/local/bin/disable-watchdog.py /usr/local/bin/disable-watchdog.py
chmod +x /usr/local/bin/client-guard.py /usr/local/bin/disable-watchdog.py
mkdir -p /etc/client-guard /opt/client-guard
[[ -f /etc/client-guard/config.json ]] || cp -f /tmp/guard-bundle/etc/client-guard/config.json /etc/client-guard/config.json
[[ -f /opt/client-guard/aux.json ]] || cp -f /tmp/guard-bundle/opt/client-guard/aux.json /opt/client-guard/aux.json
cp -f /tmp/guard-bundle/etc/systemd/system/client-guard.service /etc/systemd/system/
cp -f /tmp/guard-bundle/etc/systemd/system/client-guard-aux.service /etc/systemd/system/
cp -f /tmp/guard-bundle/etc/systemd/system/disable-watchdog.service /etc/systemd/system/
rm -rf /tmp/guard-bundle /tmp/guard-bundle.tar.gz
python3 - << 'CGPYEOF'
import json, sqlite3
try:
    db = sqlite3.connect("/etc/x-ui/x-ui.db")
    row = db.execute("SELECT value FROM settings WHERE key='xrayTemplateConfig'").fetchone()
    if row:
        cfg = json.loads(row[0])
        services = cfg.setdefault("api", {}).setdefault("services", [])
        if "RoutingService" not in services:
            services.append("RoutingService")
            db.execute("UPDATE settings SET value=? WHERE key='xrayTemplateConfig'", (json.dumps(cfg),))
            db.commit()
            print("client-guard: RoutingService added to xray template")
        else:
            print("client-guard: RoutingService already present")
    else:
        print("client-guard: xray template not seeded yet (fresh install); RoutingService will be added on the next upgrade run")
    db.close()
except Exception as e:
    print("client-guard: template patch skipped:", e)
CGPYEOF
systemctl daemon-reload
systemctl start x-ui
systemctl enable client-guard client-guard-aux disable-watchdog >/dev/null 2>&1
systemctl start client-guard client-guard-aux disable-watchdog
echo -e "${green}--------->>client-guard 已安装（每日默认 20G，超额默认限速 1024 KB/s，可改 /etc/client-guard/config.json）${plain}"
else
echo -e "${yellow}未检测到 python3，跳过 client-guard 安装：面板的超额限速将只有界面、没有执行端。装好 python3 后可重跑本脚本补装。${plain}"
fi

echo ""
echo -e "------->>>>${green}apex-panel 改版 ${MOD_VERSION}（一键新建节点版）<<<<安装成功，正在启动..."
sleep 1
echo ""
echo -e " ---------------------"
echo -e " |${green}apex-panel 控制菜单用法 ${plain}|${plain}"
echo -e " | ${yellow}一个更好的面板 ${plain}|${plain}"
echo -e " | ${yellow}基于Xray Core构建 ${plain}|${plain}"
echo -e "--------------------------------------------"
echo -e "x-ui - 进入管理脚本"
echo -e "x-ui start - 启动 apex-panel 面板"
echo -e "x-ui stop - 关闭 apex-panel 面板"
echo -e "x-ui restart - 重启 apex-panel 面板"
echo -e "x-ui status - 查看 apex-panel 状态"
echo -e "x-ui settings - 查看当前设置信息"
echo -e "x-ui enable - 启用 apex-panel 开机启动"
echo -e "x-ui disable - 禁用 apex-panel 开机启动"
echo -e "x-ui log - 查看 apex-panel 运行日志"
echo -e "x-ui banlog - 检查 Fail2ban 禁止日志"
echo -e "x-ui update - 更新 apex-panel 面板（注意：不要用它更新，否则会覆盖回官方版丢掉一键功能）"
echo -e "x-ui custom - 自定义 apex-panel 版本"
echo -e "x-ui install - 安装 apex-panel 面板"
echo -e "x-ui uninstall - 卸载 apex-panel 面板"
echo -e "--------------------------------------------"
echo ""
sleep 3
echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo -e "${yellow}----->>>改版面板和Xray启动成功<<<-----${plain}"
echo -e "${yellow}入站列表顶部有“一键新建节点”下拉：VLESS WS+TLS、VLESS REALITY、VLESS TCP、Shadowsocks、Hysteria2、Hysteria2-端口跳跃、VMess、Trojan、Socks、HTTP、WireGuard。Socks/HTTP 面板无可复制链接，需手动填客户端；Tunnel 未进一键，需手动建模板。入站列表还有一键删除全部按钮（点后先弹确认框）。主题在侧边栏主题里切，共 7 套。${plain}"
echo -e "${yellow}Hysteria2 走 UDP：若服务器开了防火墙，记得放行所建 Hysteria2 端口的 UDP。${plain}"
}

# 设置VPS中的时区/时间为
sudo timedatectl set-timezone Asia/Shanghai

install_base
install_modified
echo ""
echo -e "----------------------------------------------"
sleep 4
info=$(/usr/local/x-ui/x-ui setting -show true)
echo -e "${info}${plain}"
echo ""
echo -e "若您忘记了上述面板信息，后期可通过x-ui命令进入脚本${red}输入数字〔10〕选项获取${plain}"
echo ""
echo -e "----------------------------------------------"
echo ""
echo -e "${green}安装完成。登录面板后，到入站列表点“一键新建节点”逐个预设试建，含 Hysteria2；建完会自动弹出新节点链接。${plain}"
echo ""
