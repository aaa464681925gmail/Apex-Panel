#!/bin/bash

# ==========================================================
# R-Panel v4 安装脚本（一键新建节点版）
# 基础：官方 X-Panel install.sh 的免费版流程（xeefei/x-panel）
# 改动说明（只改安装来源与版本锁定，不碰 Pro 授权相关逻辑，
# 本脚本不索取、不校验任何授权码）：
# 1. 面板版本固定为 v26.4.25，不再去 GitHub API 取最新版。
# 取最新版会装成官方 26.9.13，改版的一键功能就丢了。
# 2. 架构只允许 amd64：改版二进制只有 x86-64 构建，
# arm64/armv7 等架构会明确报错退出，不会装错二进制。
# 3. 先下载官方 v26.4.25 包和改版二进制，两个都校验通过
# （非空、改版二进制内含“一键新建节点”和 getNewHyCert）
# 之后，才停服务、删旧目录、解压、覆盖二进制。
# 任一下载或校验失败都会在动旧安装之前退出，旧面板不受影响。
# 4. 管理脚本 x-ui.sh 固定用 v26.4.25 tag 的原始文件，
# 而不是 main 分支的最新版，以保持与二进制版本一致。
# 5. 保留官方 config_after_install() 的设账号流程：
# 选 y 依次设用户名、密码、面板端口、访问路径；
# 选 n 且全新安装时打印随机账号密码路径，之后可用 x-ui
# 菜单 10 查看；选 n 且是升级时保留旧设置。
# 6. Hysteria2 走 UDP（QUIC），与 TCP 入站不同：
# 若服务器开了防火墙，记得放行所建 Hysteria2 端口的 UDP。
# 用法（与官方命令同格式，一行）：
# bash <(curl -Ls https://raw.githubusercontent.com/aaa464681925gmail/R-Panel/main/install.sh)
# 注意：改版二进制放在本仓库的 Release v4 里，不会像临时文件链接那样过期。
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
MOD_BIN_URL="https://github.com/aaa464681925gmail/R-Panel/releases/download/v4/x-ui"
XUI_SH_URL="https://raw.githubusercontent.com/xeefei/x-panel/${MOD_VERSION}/x-ui.sh"

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
if [[! -f "/etc/x-ui/x-ui.db" ]]; then
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
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}[::1]:15208${existing_webBasePath}${plain} ${green}进入〔X-Panel面板〕登录界面"
echo ""
elif [[ -n $v4 && -n $v6 ]]; then
echo -e "${green}1、本地电脑客户端转发命令：${plain} ${blue}ssh -L 15208:127.0.0.1:${existing_port}${blue} root@$v4${plain} ${yellow}或者 ${blue}ssh -L [::]:15208:127.0.0.1:${existing_port}${blue} root@[$v6]${plain}"
echo ""
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}127.0.0.1:15208${existing_webBasePath}${plain} ${yellow}或者${plain} ${blue}[::1]:15208${existing_webBasePath}${plain} ${green}进入〔X-Panel面板〕登录界面"
echo ""
else
echo -e "${green}1、本地电脑客户端转发命令：${plain} ${blue}ssh -L 15208:127.0.0.1:${existing_port}${blue} root@$v4${plain}"
echo ""
echo -e "${green}4、请在浏览器地址栏复制${plain} ${blue}127.0.0.1:15208${existing_webBasePath}${plain} ${green}进入〔X-Panel面板〕登录界面"
echo ""
fi
echo -e "${red}注意：若不使用〔ssh转发〕请为X-Panel面板配置安装证书再行登录管理后台${plain}"
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
if [[! -s /usr/local/x-ui-linux-amd64.tar.gz ]]; then
echo -e "${red}官方基础包为空，退出安装，旧面板未动。${plain}"
exit 1
fi

echo -e "${green}--------->>下载改版面板二进制（一键新建节点版）...${plain}"
curl -fsSL ${MOD_BIN_URL} -o /tmp/x-ui.modified || {
echo -e "${red}下载改版二进制失败（链接可能已过期），退出安装，旧面板未动。${plain}"
exit 1
}
if [[! -s /tmp/x-ui.modified ]]; then
echo -e "${red}改版二进制为空，退出安装，旧面板未动。${plain}"
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
if [[ $(grep -a -c "R-XPANEL" /tmp/x-ui.modified) -ne 6 ]]; then
echo -e "${red}改版二进制校验失败：R-XPANEL 计数不是 6，退出安装，旧面板未动。${plain}"
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
chmod +x /tmp/x-ui.modified
echo -e "${green}--------->>两个文件都校验通过，开始安装...${plain}"

wget -O /usr/bin/x-ui-temp ${XUI_SH_URL} || {
echo -e "${red}下载管理脚本 x-ui.sh（${MOD_VERSION} tag）失败，退出安装，旧面板未动。${plain}"
exit 1
}
if [[! -s /usr/bin/x-ui-temp ]]; then
echo -e "${red}管理脚本为空，退出安装，旧面板未动。${plain}"
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
# ---- 第三步：用改版二进制覆盖官方二进制 ----
cp -f /tmp/x-ui.modified ./x-ui
rm -f /tmp/x-ui.modified
chmod +x x-ui
chmod +x x-ui.sh
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

echo ""
echo -e "------->>>>${green}X-Panel 改版 ${MOD_VERSION}（一键新建节点版）<<<<安装成功，正在启动..."
sleep 1
echo ""
echo -e " ---------------------"
echo -e " |${green}X-Panel 控制菜单用法 ${plain}|${plain}"
echo -e " | ${yellow}一个更好的面板 ${plain}|${plain}"
echo -e " | ${yellow}基于Xray Core构建 ${plain}|${plain}"
echo -e "--------------------------------------------"
echo -e "x-ui - 进入管理脚本"
echo -e "x-ui start - 启动 X-Panel 面板"
echo -e "x-ui stop - 关闭 X-Panel 面板"
echo -e "x-ui restart - 重启 X-Panel 面板"
echo -e "x-ui status - 查看 X-Panel 状态"
echo -e "x-ui settings - 查看当前设置信息"
echo -e "x-ui enable - 启用 X-Panel 开机启动"
echo -e "x-ui disable - 禁用 X-Panel 开机启动"
echo -e "x-ui log - 查看 X-Panel 运行日志"
echo -e "x-ui banlog - 检查 Fail2ban 禁止日志"
echo -e "x-ui update - 更新 X-Panel 面板（注意：不要用它更新，否则会覆盖回官方版丢掉一键功能）"
echo -e "x-ui custom - 自定义 X-Panel 版本"
echo -e "x-ui install - 安装 X-Panel 面板"
echo -e "x-ui uninstall - 卸载 X-Panel 面板"
echo -e "--------------------------------------------"
echo ""
sleep 3
echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo -e "${yellow}----->>>改版面板和Xray启动成功<<<-----${plain}"
echo -e "${yellow}入站列表顶部有“一键新建节点”下拉：VLESS WS+TLS、VLESS REALITY、VLESS TCP、Shadowsocks、Hysteria2、VMess、Trojan、Socks、HTTP、WireGuard。Socks/HTTP 面板无可复制链接，需手动填客户端；Tunnel 未进一键，需手动建模板。${plain}"
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
