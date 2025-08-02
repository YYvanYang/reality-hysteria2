#!/usr/bin/env bash
# reality-hysteria2.sh - REALITY + Hysteria2 一键安装脚本
# 版本: 2.0.0 优化版
# 作者: YYvanYang
# 描述: 一键部署 VLESS REALITY (xray-core) 和 Hysteria2 双协议代理服务器
# 支持: Ubuntu/Debian/CentOS 系统

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
CLEAR='\033[0m'

# 打印函数
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# 欢迎信息
clear
print_with_delay "REALITY + Hysteria2 一键安装脚本 v2.0" 0.03
echo ""
echo -e "${GREEN}========================================${CLEAR}"
echo -e "${GREEN}  支持: VLESS REALITY + Hysteria2${CLEAR}"
echo -e "${GREEN}  系统: Ubuntu/Debian/CentOS${CLEAR}"
echo -e "${GREEN}  作者: YYvanYang (优化版)${CLEAR}"
echo -e "${GREEN}========================================${CLEAR}"
echo ""

# 检查 root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 请使用 root 权限运行此脚本${CLEAR}"
   echo "使用: sudo bash $0"
   exit 1
fi

# 检查系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}无法检测系统类型${CLEAR}"
    exit 1
fi

# 安装基础工具
install_base() {
    echo -e "${YELLOW}安装基础工具...${CLEAR}"
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        apt update -y >/dev/null 2>&1
        apt install -y curl wget unzip openssl >/dev/null 2>&1
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "fedora" ]]; then
        yum install -y curl wget unzip openssl >/dev/null 2>&1
    fi
    echo -e "${GREEN}✓ 基础工具安装完成${CLEAR}"
}

# 检查是否已安装
if [ -f "/etc/proxy-server/installed" ]; then
    echo -e "${YELLOW}检测到已安装${CLEAR}"
    echo ""
    echo "1. 重新安装"
    echo "2. 查看配置"
    echo "3. 卸载"
    echo ""
    read -p "请选择 [1-3]: " choice
    
    case $choice in
        1)
            echo "重新安装..."
            rm -rf /etc/proxy-server
            systemctl stop xray-reality hysteria2 2>/dev/null
            systemctl disable xray-reality hysteria2 2>/dev/null
            rm -f /etc/systemd/system/xray-reality.service
            rm -f /etc/systemd/system/hysteria2.service
            ;;
        2)
            cat /etc/proxy-server/client-info.txt
            exit 0
            ;;
        3)
            echo "卸载中..."
            systemctl stop xray-reality hysteria2 2>/dev/null
            systemctl disable xray-reality hysteria2 2>/dev/null
            rm -rf /etc/proxy-server
            rm -f /etc/systemd/system/xray-reality.service
            rm -f /etc/systemd/system/hysteria2.service
            rm -f /usr/local/bin/proxy-manager
            rm -f /usr/local/bin/pm
            echo -e "${GREEN}卸载完成${CLEAR}"
            exit 0
            ;;
        *)
            echo "无效选择"
            exit 1
            ;;
    esac
fi

# 安装基础工具
install_base

# 创建目录
mkdir -p /etc/proxy-server/{xray,hysteria,certs}
cd /etc/proxy-server

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) 
        XRAY_ARCH="64"
        HY_ARCH="amd64"
        ;;
    aarch64) 
        XRAY_ARCH="arm64-v8a"
        HY_ARCH="arm64"
        ;;
    *) echo -e "${RED}不支持的架构: $ARCH${CLEAR}"; exit 1 ;;
esac

echo -e "${GREEN}系统架构: $ARCH (xray: $XRAY_ARCH, hysteria: $HY_ARCH)${CLEAR}"
echo ""

# 获取配置参数并验证
while true; do
    read -p "Reality 端口 (默认 443): " REALITY_PORT
    REALITY_PORT=${REALITY_PORT:-443}
    if [[ "$REALITY_PORT" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$REALITY_PORT" -le 65535 ]; then
        break
    fi
    echo -e "${RED}错误: 请输入有效端口号 (1-65535)${CLEAR}"
done

while true; do
    read -p "Hysteria2 端口 (默认 8443): " HYSTERIA_PORT
    HYSTERIA_PORT=${HYSTERIA_PORT:-8443}
    if [[ "$HYSTERIA_PORT" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$HYSTERIA_PORT" -le 65535 ]; then
        break
    fi
    echo -e "${RED}错误: 请输入有效端口号 (1-65535)${CLEAR}"
done

read -p "域名 (可选，用于 Hysteria2 证书): " DOMAIN
if [ -n "$DOMAIN" ] && ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    echo -e "${RED}警告: 域名格式不正确，将使用自签名证书${CLEAR}"
    DOMAIN=""
fi
echo ""

# 下载和验证 xray
echo -e "${YELLOW}下载 xray-core...${CLEAR}"
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
if [ -z "$XRAY_VERSION" ] || [ "$XRAY_VERSION" = "null" ]; then
    echo -e "${RED}获取 xray 版本信息失败${CLEAR}"
    exit 1
fi

wget -q --show-progress "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip" -O xray.zip
if [ ! -s "xray.zip" ]; then
    echo -e "${RED}xray 下载失败${CLEAR}"
    exit 1
fi

unzip -q xray.zip -d xray/ || {
    echo -e "${RED}xray 解压失败${CLEAR}"
    exit 1
}
chmod +x xray/xray
rm xray.zip
echo -e "${GREEN}✓ xray-core ${XRAY_VERSION} 安装完成${CLEAR}"

# 下载和验证 hysteria
echo -e "${YELLOW}下载 Hysteria2...${CLEAR}"
HY_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
if [ -z "$HY_VERSION" ] || [ "$HY_VERSION" = "null" ]; then
    echo -e "${RED}获取 Hysteria2 版本信息失败${CLEAR}"
    exit 1
fi

wget -q --show-progress "https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/hysteria-linux-${HY_ARCH}" -O hysteria/hysteria
if [ ! -s "hysteria/hysteria" ]; then
    echo -e "${RED}Hysteria2 下载失败${CLEAR}"
    exit 1
fi

chmod +x hysteria/hysteria
echo -e "${GREEN}✓ Hysteria2 ${HY_VERSION} 安装完成${CLEAR}"

# 生成 Reality 配置
echo -e "${YELLOW}生成配置...${CLEAR}"
cd /etc/proxy-server/xray
KEY_PAIR=$(./xray x25519)
PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "Private key:" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "Public key:" | awk '{print $3}')
UUID=$(./xray uuid)
SHORT_ID=$(openssl rand -hex 8)

# xray 配置
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $REALITY_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# Hysteria2 配置
cd /etc/proxy-server/hysteria
HY_PASSWORD=$(openssl rand -base64 32)

if [ -n "$DOMAIN" ]; then
    cat > config.yaml <<EOF
listen: :$HYSTERIA_PORT

acme:
  domains:
    - $DOMAIN
  email: admin@$DOMAIN

auth:
  type: password
  password: "$HY_PASSWORD"

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

bandwidth:
  up: 1000 mbps
  down: 1000 mbps

ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
EOF
else
    # 自签名证书
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/proxy-server/certs/hy.key \
        -out /etc/proxy-server/certs/hy.crt \
        -subj "/CN=bing.com" -days 36500 >/dev/null 2>&1
        
    cat > config.yaml <<EOF
listen: :$HYSTERIA_PORT

tls:
  cert: /etc/proxy-server/certs/hy.crt
  key: /etc/proxy-server/certs/hy.key

auth:
  type: password
  password: "$HY_PASSWORD"

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

bandwidth:
  up: 1000 mbps
  down: 1000 mbps

ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
EOF
fi

# 创建 systemd 服务
cat > /etc/systemd/system/xray-reality.service <<EOF
[Unit]
Description=Xray REALITY
After=network.target

[Service]
Type=simple
ExecStart=/etc/proxy-server/xray/xray run -c /etc/proxy-server/xray/config.json
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/hysteria2.service <<EOF
[Unit]
Description=Hysteria2
After=network.target

[Service]
Type=simple
ExecStart=/etc/proxy-server/hysteria/hysteria server -c /etc/proxy-server/hysteria/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 优化系统
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1

# 启动服务
systemctl daemon-reload
systemctl enable xray-reality hysteria2 >/dev/null 2>&1
systemctl start xray-reality hysteria2 >/dev/null 2>&1

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${CLEAR}"
for service in xray-reality hysteria2; do
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓ $service 服务运行正常${CLEAR}"
    else
        echo -e "${RED}✗ $service 服务启动失败${CLEAR}"
        echo "错误日志:"
        journalctl -u "$service" --no-pager -n 3
    fi
done

# 获取 IP
SERVER_IP=$(curl -s4 https://api.ipify.org || curl -s4 ifconfig.me)

# 确定 Hysteria2 连接地址
if [ -n "$DOMAIN" ]; then
    HY_SERVER=$DOMAIN
    HY_TAG="Hysteria2-${DOMAIN}"
else
    HY_SERVER=$SERVER_IP
    HY_TAG="Hysteria2-${SERVER_IP}"
fi

# 生成客户端信息
cat > /etc/proxy-server/client-info.txt <<EOF
========================================
         代理服务器配置信息
========================================

服务器 IP: $SERVER_IP
$([ -n "$DOMAIN" ] && echo "域名: $DOMAIN")

----- VLESS REALITY -----
端口: $REALITY_PORT
UUID: $UUID
Flow: xtls-rprx-vision
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID

vless://${UUID}@${SERVER_IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none\#Reality-${SERVER_IP}

----- Hysteria2 -----
端口: $HYSTERIA_PORT
密码: $HY_PASSWORD
$([ -n "$DOMAIN" ] && echo "域名: $DOMAIN")

hysteria2://${HY_PASSWORD}@${HY_SERVER}:${HYSTERIA_PORT}/?sni=${DOMAIN:-bing.com}$([ -z "$DOMAIN" ] && echo "&insecure=1")\#${HY_TAG}

========================================
EOF

# 设置文件权限
chmod 600 /etc/proxy-server/client-info.txt
chmod 600 /etc/proxy-server/xray/config.json
chmod 600 /etc/proxy-server/hysteria/config.yaml
chown -R root:root /etc/proxy-server/

# 创建管理脚本
cat > /usr/local/bin/proxy-manager <<'EOF'
#!/bin/bash
case "$1" in
    status)
        echo "=== 服务状态 ==="
        for service in xray-reality hysteria2; do
            echo "[$service]"
            systemctl is-active --quiet "$service" && echo "状态: 运行中" || echo "状态: 已停止"
            echo "进程: $(systemctl show -p MainPID --value "$service")"
            echo ""
        done
        ;;
    info)
        cat /etc/proxy-server/client-info.txt
        ;;
    restart)
        systemctl restart xray-reality hysteria2
        echo "服务已重启"
        ;;
    start)
        systemctl start xray-reality hysteria2
        echo "服务已启动"
        ;;
    stop)
        systemctl stop xray-reality hysteria2
        echo "服务已停止"
        ;;
    log)
        case "$2" in
            xray)
                journalctl -u xray-reality -f
                ;;
            hysteria)
                journalctl -u hysteria2 -f
                ;;
            "")
                echo "实时日志 (Ctrl+C 退出):"
                journalctl -u xray-reality -u hysteria2 -f
                ;;
            *)
                echo "用法: $0 log [xray|hysteria]"
                ;;
        esac
        ;;
    *)
        echo "用法: $0 {status|info|restart|start|stop|log}"
        echo "  status   - 查看服务状态"
        echo "  info     - 显示客户端配置"
        echo "  restart  - 重启服务"
        echo "  start    - 启动服务"
        echo "  stop     - 停止服务"
        echo "  log      - 查看日志"
        ;;
esac
EOF
chmod +x /usr/local/bin/proxy-manager

# 创建简短别名
ln -sf /usr/local/bin/proxy-manager /usr/local/bin/pm

# 标记已安装
touch /etc/proxy-server/installed

# 显示结果
clear
echo -e "${GREEN}========================================${CLEAR}"
echo -e "${GREEN}         安装完成！${CLEAR}"
echo -e "${GREEN}========================================${CLEAR}"
echo ""
cat /etc/proxy-server/client-info.txt
echo ""
echo -e "${YELLOW}管理命令:${CLEAR}"
echo "  proxy-manager status  - 查看状态"
echo "  proxy-manager info    - 显示配置"
echo "  proxy-manager restart - 重启服务"
echo "  proxy-manager log     - 查看日志"
echo "  或使用简写: pm status, pm info, pm restart"
echo ""