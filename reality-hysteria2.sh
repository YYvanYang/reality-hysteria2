#!/usr/bin/env bash
# reality-hysteria2.sh - VLESS REALITY + Hysteria2 一键安装脚本
# 支持 xray-core (REALITY) 和 Hysteria2 双协议部署

set -euo pipefail

# 版本信息
SCRIPT_VERSION="1.0.0"
XRAY_VERSION=""  # 留空使用最新版
HYSTERIA_VERSION=""  # 留空使用最新版

# 默认配置
REALITY_PORT="${REALITY_PORT:-443}"
HYSTERIA_PORT="${HYSTERIA_PORT:-8443}"
REALITY_SNI="${REALITY_SNI:-www.cloudflare.com}"

# 路径定义
WORK_DIR="/etc/proxy-server"
XRAY_DIR="$WORK_DIR/xray"
HYSTERIA_DIR="$WORK_DIR/hysteria"
CERT_DIR="$WORK_DIR/certs"
LOG_DIR="/var/log/proxy-server"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
CLEAR='\033[0m'

# 辅助函数
msg_info() { echo -e "${GREEN}[INFO]${CLEAR} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${CLEAR} $1"; }
msg_err() { echo -e "${RED}[ERROR]${CLEAR} $1"; }
msg_ok() { echo -e "${GREEN}[✓]${CLEAR} $1"; }

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_err "此脚本需要 root 权限运行"
        msg_info "请使用: sudo bash $0"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        msg_err "无法检测系统类型"
        exit 1
    fi
    
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" && "$OS" != "centos" && "$OS" != "fedora" ]]; then
        msg_err "不支持的系统: $OS"
        msg_info "支持: Ubuntu/Debian/CentOS/Fedora"
        exit 1
    fi
    
    msg_ok "检测到系统: $PRETTY_NAME"
}

# 检查架构
check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH_TYPE="amd64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            ;;
        *)
            msg_err "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    msg_ok "系统架构: $ARCH_TYPE"
}

# 安装依赖
install_deps() {
    msg_info "安装系统依赖..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update -y
        apt-get install -y \
            curl wget unzip tar jq openssl uuid-runtime \
            ca-certificates lsb-release gnupg socat cron
    elif [[ "$OS" == "centos" || "$OS" == "fedora" ]]; then
        yum install -y epel-release
        yum install -y \
            curl wget unzip tar jq openssl util-linux \
            ca-certificates gnupg2 socat cronie
    fi
    
    # 安装 acme.sh (用于 Hysteria2 证书)
    if [[ ! -f "$HOME/.acme.sh/acme.sh" ]]; then
        msg_info "安装 acme.sh..."
        curl -fsSL https://get.acme.sh | sh -s email=admin@example.com
        source "$HOME/.acme.sh/acme.sh.env"
    fi
}

# 创建目录结构
create_dirs() {
    mkdir -p "$XRAY_DIR" "$HYSTERIA_DIR" "$CERT_DIR" "$LOG_DIR"
    chmod 755 "$WORK_DIR"
}

# 下载 xray-core
download_xray() {
    msg_info "下载 xray-core..."
    
    local api_url="https://api.github.com/repos/XTLS/Xray-core/releases/latest"
    if [[ -n "$XRAY_VERSION" ]]; then
        api_url="https://api.github.com/repos/XTLS/Xray-core/releases/tags/$XRAY_VERSION"
    fi
    
    local download_url=$(curl -s "$api_url" | jq -r --arg arch "$ARCH_TYPE" \
        '.assets[] | select(.name | test("linux-" + $arch + ".zip")) | .browser_download_url')
    
    if [[ -z "$download_url" ]]; then
        msg_err "无法获取 xray-core 下载链接"
        exit 1
    fi
    
    wget -q --show-progress -O /tmp/xray.zip "$download_url"
    unzip -q -o /tmp/xray.zip -d "$XRAY_DIR"
    chmod +x "$XRAY_DIR/xray"
    rm -f /tmp/xray.zip
    
    msg_ok "xray-core 安装完成: $($XRAY_DIR/xray version | head -1)"
}

# 下载 Hysteria2
download_hysteria() {
    msg_info "下载 Hysteria2..."
    
    local api_url="https://api.github.com/repos/apernet/hysteria/releases/latest"
    if [[ -n "$HYSTERIA_VERSION" ]]; then
        api_url="https://api.github.com/repos/apernet/hysteria/releases/tags/$HYSTERIA_VERSION"
    fi
    
    local download_url=$(curl -s "$api_url" | jq -r --arg arch "$ARCH_TYPE" \
        '.assets[] | select(.name | test("linux-" + $arch)) | .browser_download_url')
    
    if [[ -z "$download_url" ]]; then
        msg_err "无法获取 Hysteria2 下载链接"
        exit 1
    fi
    
    wget -q --show-progress -O "$HYSTERIA_DIR/hysteria" "$download_url"
    chmod +x "$HYSTERIA_DIR/hysteria"
    
    msg_ok "Hysteria2 安装完成: $($HYSTERIA_DIR/hysteria version | head -1)"
}

# 生成 Reality 密钥
generate_reality_keys() {
    msg_info "生成 REALITY 密钥..."
    
    # 生成密钥对
    local keys=$($XRAY_DIR/xray x25519)
    REALITY_PRIVATE_KEY=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
    REALITY_PUBLIC_KEY=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
    
    # 生成 UUID
    REALITY_UUID=$(uuidgen)
    
    # 生成 short_id
    REALITY_SHORT_ID=$(openssl rand -hex 8)
    
    msg_ok "REALITY 密钥生成完成"
}

# 生成 Hysteria2 配置
generate_hysteria_config() {
    msg_info "生成 Hysteria2 配置..."
    
    # 生成密码
    HYSTERIA_PASSWORD=$(openssl rand -base64 32)
    
    # 如果有域名，配置证书
    if [[ -n "${DOMAIN:-}" ]]; then
        cat > "$HYSTERIA_DIR/config.yaml" <<EOF
listen: :$HYSTERIA_PORT

acme:
  domains:
    - $DOMAIN
  email: admin@$DOMAIN

auth:
  type: password
  password: "$HYSTERIA_PASSWORD"

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
        # 自签名证书配置
        msg_info "未指定域名，使用自签名证书"
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
            -keyout "$CERT_DIR/hysteria.key" \
            -out "$CERT_DIR/hysteria.crt" \
            -subj "/CN=bing.com" -days 36500
        
        cat > "$HYSTERIA_DIR/config.yaml" <<EOF
listen: :$HYSTERIA_PORT

tls:
  cert: $CERT_DIR/hysteria.crt
  key: $CERT_DIR/hysteria.key

auth:
  type: password
  password: "$HYSTERIA_PASSWORD"

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
}

# 生成 xray 配置
generate_xray_config() {
    msg_info "生成 xray-core 配置..."
    
    cat > "$XRAY_DIR/config.json" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/xray-access.log",
    "error": "$LOG_DIR/xray-error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $REALITY_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$REALITY_UUID",
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
          "dest": "$REALITY_SNI:443",
          "xver": 0,
          "serverNames": [
            "$REALITY_SNI"
          ],
          "privateKey": "$REALITY_PRIVATE_KEY",
          "shortIds": [
            "$REALITY_SHORT_ID"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
EOF
}

# 创建 systemd 服务
create_services() {
    msg_info "创建系统服务..."
    
    # xray 服务
    cat > /etc/systemd/system/xray-reality.service <<EOF
[Unit]
Description=Xray REALITY Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$XRAY_DIR/xray run -c $XRAY_DIR/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    # hysteria2 服务
    cat > /etc/systemd/system/hysteria2.service <<EOF
[Unit]
Description=Hysteria2 Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$HYSTERIA_DIR/hysteria server -c $HYSTERIA_DIR/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
}

# 优化系统
optimize_system() {
    msg_info "优化系统参数..."
    
    # 优化内核参数
    cat > /etc/sysctl.d/99-proxy-server.conf <<EOF
# 网络优化
net.ipv4.tcp_keepalive_time = 90
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0

# UDP 优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.udp_mem = 8388608 16777216 16777216

# 文件描述符
fs.file-max = 1048576
EOF
    
    sysctl -p /etc/sysctl.d/99-proxy-server.conf > /dev/null 2>&1
    
    # 优化 limits
    cat > /etc/security/limits.d/99-proxy-server.conf <<EOF
* soft nproc 1048576
* hard nproc 1048576
* soft nofile 1048576
* hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
}

# 启动服务
start_services() {
    msg_info "启动服务..."
    
    systemctl enable xray-reality hysteria2
    systemctl restart xray-reality hysteria2
    
    sleep 2
    
    if systemctl is-active --quiet xray-reality; then
        msg_ok "Xray REALITY 服务启动成功"
    else
        msg_err "Xray REALITY 服务启动失败"
        journalctl -u xray-reality --no-pager -n 10
    fi
    
    if systemctl is-active --quiet hysteria2; then
        msg_ok "Hysteria2 服务启动成功"
    else
        msg_err "Hysteria2 服务启动失败"
        journalctl -u hysteria2 --no-pager -n 10
    fi
}

# 生成客户端配置
generate_client_configs() {
    local server_ip="${SERVER_IP:-$(curl -s4 ip.sb || curl -s4 ifconfig.me)}"
    
    # 保存配置信息
    cat > "$WORK_DIR/client-info.txt" <<EOF
========================================
         代理服务器配置信息
========================================

服务器 IP: $server_ip

----- VLESS + REALITY + Vision -----
端口: $REALITY_PORT
UUID: $REALITY_UUID
Flow: xtls-rprx-vision
SNI: $REALITY_SNI
Public Key: $REALITY_PUBLIC_KEY
Short ID: $REALITY_SHORT_ID

VLESS URI:
vless://${REALITY_UUID}@${server_ip}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp&headerType=none#REALITY-${server_ip}

----- Hysteria2 -----
端口: $HYSTERIA_PORT
密码: $HYSTERIA_PASSWORD
SNI: ${DOMAIN:-bing.com}
自签名证书: $([ -z "${DOMAIN:-}" ] && echo "是" || echo "否")

Hysteria2 URI:
hysteria2://${HYSTERIA_PASSWORD}@${server_ip}:${HYSTERIA_PORT}/?sni=${DOMAIN:-bing.com}$([ -z "${DOMAIN:-}" ] && echo "&insecure=1" || echo "")#Hysteria2-${server_ip}

========================================
EOF

    # 显示配置信息
    cat "$WORK_DIR/client-info.txt"
}

# 创建管理脚本
create_management_script() {
    cat > /usr/local/bin/proxy-manager <<'EOF'
#!/bin/bash

WORK_DIR="/etc/proxy-server"

case "$1" in
    status)
        echo "=== 服务状态 ==="
        systemctl status xray-reality --no-pager | grep -E "(Active:|Main PID:)"
        systemctl status hysteria2 --no-pager | grep -E "(Active:|Main PID:)"
        ;;
    restart)
        systemctl restart xray-reality hysteria2
        echo "服务已重启"
        ;;
    stop)
        systemctl stop xray-reality hysteria2
        echo "服务已停止"
        ;;
    start)
        systemctl start xray-reality hysteria2
        echo "服务已启动"
        ;;
    info)
        cat "$WORK_DIR/client-info.txt"
        ;;
    log)
        case "$2" in
            xray)
                journalctl -u xray-reality -f
                ;;
            hysteria)
                journalctl -u hysteria2 -f
                ;;
            *)
                echo "使用: $0 log [xray|hysteria]"
                ;;
        esac
        ;;
    *)
        echo "使用: $0 {status|restart|stop|start|info|log}"
        echo "  status   - 查看服务状态"
        echo "  restart  - 重启所有服务"
        echo "  stop     - 停止所有服务"
        echo "  start    - 启动所有服务"
        echo "  info     - 显示客户端配置"
        echo "  log      - 查看日志"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/proxy-manager
    
    # 创建简短别名
    ln -sf /usr/local/bin/proxy-manager /usr/local/bin/pm
}

# 卸载函数
uninstall() {
    msg_warn "开始卸载..."
    
    systemctl stop xray-reality hysteria2 2>/dev/null || true
    systemctl disable xray-reality hysteria2 2>/dev/null || true
    
    rm -rf "$WORK_DIR"
    rm -f /etc/systemd/system/xray-reality.service
    rm -f /etc/systemd/system/hysteria2.service
    rm -f /usr/local/bin/proxy-manager
    rm -f /usr/local/bin/pm
    rm -f /etc/sysctl.d/99-proxy-server.conf
    rm -f /etc/security/limits.d/99-proxy-server.conf
    
    systemctl daemon-reload
    
    msg_ok "卸载完成"
}

# 主安装流程
install() {
    msg_info "开始安装 REALITY + Hysteria2 代理服务器..."
    
    check_system
    check_arch
    install_deps
    create_dirs
    
    # 下载程序
    download_xray
    download_hysteria
    
    # 生成配置
    generate_reality_keys
    generate_xray_config
    generate_hysteria_config
    
    # 创建服务
    create_services
    optimize_system
    start_services
    
    # 管理工具
    create_management_script
    
    # 显示配置
    generate_client_configs
    
    msg_ok "安装完成！"
    echo
    msg_info "管理命令："
    echo "  proxy-manager status  - 查看状态"
    echo "  proxy-manager info    - 显示配置"
    echo "  pm log xray          - 查看 xray 日志"
    echo "  pm log hysteria      - 查看 hysteria 日志"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${PURPLE}================================${CLEAR}"
    echo -e "${PURPLE}  REALITY + Hysteria2 安装脚本${CLEAR}"
    echo -e "${PURPLE}       Version: $SCRIPT_VERSION${CLEAR}"
    echo -e "${PURPLE}================================${CLEAR}"
    echo
    echo "1. 安装 REALITY + Hysteria2"
    echo "2. 查看配置信息"
    echo "3. 卸载"
    echo "0. 退出"
    echo
}

# 主函数
main() {
    check_root
    
    # 处理命令行参数
    case "${1:-}" in
        install)
            install
            ;;
        uninstall)
            uninstall
            ;;
        info)
            if [[ -f "$WORK_DIR/client-info.txt" ]]; then
                cat "$WORK_DIR/client-info.txt"
            else
                msg_err "未找到配置信息，请先安装"
            fi
            ;;
        *)
            show_menu
            read -p "请选择 [0-3]: " choice
            case $choice in
                1)
                    read -p "请输入 Reality 端口 [默认: 443]: " REALITY_PORT
                    REALITY_PORT=${REALITY_PORT:-443}
                    
                    read -p "请输入 Hysteria2 端口 [默认: 8443]: " HYSTERIA_PORT
                    HYSTERIA_PORT=${HYSTERIA_PORT:-8443}
                    
                    read -p "请输入域名 (留空使用自签名证书): " DOMAIN
                    
                    install
                    ;;
                2)
                    if [[ -f "$WORK_DIR/client-info.txt" ]]; then
                        cat "$WORK_DIR/client-info.txt"
                    else
                        msg_err "未找到配置信息"
                    fi
                    ;;
                3)
                    read -p "确定要卸载吗? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        uninstall
                    fi
                    ;;
                0)
                    exit 0
                    ;;
                *)
                    msg_err "无效选择"
                    ;;
            esac
            ;;
    esac
}

# 运行主函数
main "$@"