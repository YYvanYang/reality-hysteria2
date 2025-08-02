# REALITY + Hysteria2 一键安装脚本

一键部署 VLESS REALITY (xray-core) 和 Hysteria2 双协议代理服务器。

## ✨ 特性

- 🚀 **双协议支持**：同时部署 VLESS REALITY 和 Hysteria2
- 🔒 **最强抗封锁**：REALITY 协议完美伪装，无需域名证书
- ⚡ **极速传输**：Hysteria2 基于 QUIC，速度是 TCP 的 1.5-2 倍
- 🛠️ **一键部署**：自动检测系统、安装依赖、优化配置
- 📊 **智能管理**：内置管理命令，轻松查看状态和日志
- 🔧 **自动优化**：BBR、系统参数自动优化
- 🔐 **安全防护**：自动文件权限设置和输入验证
- 🔄 **智能检测**：自动下载验证和服务状态检查

## 📋 系统要求

- **操作系统**: Ubuntu 20.04+, Debian 10+, CentOS 7+
- **架构**: x86_64, ARM64
- **内存**: 建议 512MB 以上
- **磁盘空间**: 最少 1GB 可用空间
- **网络**: 公网 IP 地址（IPv4 或 IPv6）
- **端口**: 需要开放指定端口（默认 443 和 8443）
- **权限**: Root 用户或 sudo 权限

## 🚀 快速开始

### 一键安装

```bash
# 交互式安装（推荐）
bash <(curl -fsSL https://raw.githubusercontent.com/YYvanYang/reality-hysteria2/main/reality-hysteria2.sh)

# 快速安装（跳过菜单）
bash <(curl -fsSL https://raw.githubusercontent.com/YYvanYang/reality-hysteria2/main/reality-hysteria2.sh) install
```

> ⚠️ **安全提醒**: 请在执行任何脚本前先查看其内容，确保来源可信。

## 📖 使用说明

### 管理命令

安装后可以使用 `proxy-manager` 或简写 `pm` 命令：

```bash
# 查看服务状态
proxy-manager status

# 查看客户端配置
proxy-manager info

# 重启服务
proxy-manager restart

# 停止服务
proxy-manager stop

# 启动服务
proxy-manager start

# 查看实时日志
pm log xray      # 查看 REALITY 日志
pm log hysteria  # 查看 Hysteria2 日志
```

### 查看配置

安装完成后，配置信息会自动显示并保存在 `/etc/proxy-server/client-info.txt`

随时查看配置：
```bash
cat /etc/proxy-server/client-info.txt
```

## 🔧 高级配置

### 环境变量

可以通过环境变量自定义安装：

```bash
# 自定义端口
REALITY_PORT=8443 HYSTERIA_PORT=9443 bash reality-hysteria2.sh install

# 指定 SNI
REALITY_SNI=www.amazon.com bash reality-hysteria2.sh install

# 指定服务器 IP（多网卡时使用）
SERVER_IP=1.2.3.4 bash reality-hysteria2.sh install
```

### 使用域名（Hysteria2 证书）

如果您有域名，可以让 Hysteria2 自动申请证书：

```bash
# 安装时输入域名
bash reality-hysteria2.sh
# 选择 1 安装
# 在域名提示处输入您的域名
```

**注意**：域名需要正确解析到服务器 IP

## 📱 客户端配置

### 支持的客户端

#### VLESS REALITY 客户端
- **v2rayN** (Windows)
- **v2rayNG** (Android) 
- **FoXray** (iOS)
- **Qv2ray** (Linux/macOS)
- **Xray-core** (命令行)

#### Hysteria2 客户端
- **Clash Meta** (跨平台)
- **sing-box** (跨平台)
- **NekoBox** (Android)
- **Hiddify** (iOS/Android)
- **Hysteria** (命令行)

> 📝 **注意**: 请使用支持 REALITY 和 Hysteria2 的最新版本客户端

### 导入配置

1. 获取配置：`proxy-manager info`
2. 复制 URI 到客户端导入
3. 测试连接

## 🔍 故障排查

### 基本检查
```bash
# 服务状态
proxy-manager status

# 查看日志
proxy-manager log xray      # REALITY
proxy-manager log hysteria  # Hysteria2

# 检查端口
ss -tlnp | grep 443   # TCP
ss -ulnp | grep 8443  # UDP
```

### 常见问题
- **端口占用**: `lsof -i:443` 检查，或修改端口 `REALITY_PORT=8443`
- **时间不同步**: `timedatectl set-ntp true`
- **防火墙**: `ufw allow 443/tcp && ufw allow 8443/udp`

## 🔄 更新与卸载

### 更新程序
```bash
# 重新运行安装脚本即可更新
bash reality-hysteria2.sh install
```

### 完全卸载
```bash
bash reality-hysteria2.sh uninstall
```

## 🛡️ 安全建议

1. **定期更新**：保持 xray-core 和 hysteria 最新版本
2. **防火墙设置**：仅开放必要端口，限制访问来源
3. **密码管理**：使用强密码和定期更换 UUID/密码
4. **监控日志**：定期检查异常访问和攻击记录
5. **系统加固**：禁用不必要的服务，定期更新系统
6. **备份配置**：定期备份配置文件

## 📊 性能优化

脚本已自动进行以下优化：
- ✅ 启用 BBR 拥塞控制
- ✅ 优化系统 TCP 参数
- ✅ 增大文件描述符限制
- ✅ UDP 缓冲区优化

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## ⚠️ 免责声明

本项目仅供学习研究使用。使用者应遵守当地法律法规，作者不承担任何使用风险和法律责任。

---

**提示**：遇到问题请先查看 [Wiki](https://github.com/YYvanYang/reality-hysteria2/wiki) 或提交 [Issue](https://github.com/YYvanYang/reality-hysteria2/issues)