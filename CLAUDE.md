# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Style and Conventions

- Use 4-space indentation for bash scripts
- No `set -euo pipefail` in this script (interactive nature requires error tolerance)
- Avoid inline comments after code (use `\#` for URI anchors)
- All sensitive files must have 600 permissions
- Use `proxy-manager` or `pm` for service management commands
- Configuration files are dynamically generated, not templated

## Documentation Search Guidelines

- **IMPORTANT**: When searching for official documentation or checking for updates, use version/date constraints rather than "current" or "latest"
- Search for "Xray REALITY 2024 2025" instead of "latest Xray REALITY"
- Search for "Hysteria2 v2.x documentation" rather than "current Hysteria2 docs"
- This ensures finding the most recent information rather than potentially outdated "current" results

## Required Dependencies

- `curl`, `wget`, `unzip`, `openssl`, `jq` (auto-installed)
- Root privileges required for installation
- Supported OS: Ubuntu 20.04+, Debian 10+, CentOS 7+
- Architecture: x86_64, ARM64

## Project Overview

This is a one-click installation script for deploying VLESS REALITY (xray-core) and Hysteria2 dual-protocol proxy servers. The project consists of:

- **Main script**: `reality-hysteria2.sh` - Bash installation script with interactive menus
- **Documentation**: `README.md` - Comprehensive user guide and troubleshooting

## Core Architecture

### Installation Script Structure (`reality-hysteria2.sh`)

**Entry Point and Flow:**
1. **Pre-installation checks** - Detects existing installations, offers reinstall/uninstall options
2. **System verification** - OS detection, architecture check, dependency installation  
3. **Binary download** - Fetches latest Xray-core and Hysteria2 releases with verification
4. **Configuration generation** - Creates optimized configs for both protocols
5. **Service deployment** - Sets up systemd services with proper permissions
6. **Management tools** - Installs `proxy-manager` command with `pm` alias

**Key Functions:**
- `install_base()` - Installs system dependencies (curl, wget, unzip, openssl, jq)
- `print_with_delay()` - Animated text output for user experience
- Configuration generators for Xray REALITY and Hysteria2
- Service status validation and error handling

**File System Layout (Post-Installation):**
```
/etc/proxy-server/                     # Main installation directory
├── xray/
│   ├── xray                          # Xray-core binary (755)
│   └── config.json                   # REALITY configuration (600)
├── hysteria/
│   ├── hysteria                      # Hysteria2 binary (755)
│   └── config.yaml                   # Hysteria2 configuration (600)
├── certs/                            # Self-signed certificates (if no domain)
│   ├── hy.crt
│   └── hy.key
├── client-info.txt                   # Generated connection URIs (600)
└── installed                         # Installation marker file

/etc/systemd/system/
├── xray-reality.service              # REALITY systemd unit
└── hysteria2.service                 # Hysteria2 systemd unit

/usr/local/bin/
├── proxy-manager                     # Management script (755)
└── pm -> proxy-manager               # Symbolic link alias
```

## Protocol Configurations

### VLESS REALITY Configuration
- **Flow**: `xtls-rprx-vision` (latest recommended)
- **Target SNI**: `www.microsoft.com` (configurable via environment)
- **Security**: Reality protocol eliminates TLS fingerprints
- **Port**: Default 443 (TCP)

### Hysteria2 Configuration  
- **Transport**: QUIC-based with performance optimizations
- **Authentication**: Password-based
- **Certificates**: Auto ACME or self-signed fallback
- **Port**: Default 8443 (UDP)
- **Performance**: Optimized QUIC windows and bandwidth settings

## Frequently Used Commands

### Script Execution

```bash
# Interactive installation (recommended for testing)
sudo bash reality-hysteria2.sh

# Silent installation with environment variables
REALITY_PORT=8443 HYSTERIA_PORT=9443 sudo bash reality-hysteria2.sh install

# Custom SNI configuration
REALITY_SNI=www.amazon.com sudo bash reality-hysteria2.sh install

# Uninstall
sudo bash reality-hysteria2.sh
# Then select option 3
```

### Service Management

```bash
# Service status and control
proxy-manager status        # Check both services
proxy-manager restart       # Restart both services
proxy-manager start         # Start both services  
proxy-manager stop          # Stop both services

# Configuration and monitoring
proxy-manager info          # Show client connection details
proxy-manager log           # View combined logs
proxy-manager log xray      # REALITY-specific logs
proxy-manager log hysteria  # Hysteria2-specific logs

# Alternative using short alias
pm status
pm info
pm restart
```

### Debugging and Verification

```bash
# Port availability check
ss -tlnp | grep 443         # TCP port for REALITY
ss -ulnp | grep 8443        # UDP port for Hysteria2
lsof -i:443                 # What's using the port

# Binary and configuration verification
ls -la /etc/proxy-server/   # Check file structure
file /etc/proxy-server/xray/xray          # Verify binary type
file /etc/proxy-server/hysteria/hysteria  # Verify binary type
cat /etc/proxy-server/client-info.txt     # Direct config access

# System service debugging
systemctl status xray-reality hysteria2   # Service status
journalctl -u xray-reality -f             # Live REALITY logs
journalctl -u hysteria2 -f                # Live Hysteria2 logs
systemctl --failed                         # Check failed services

# Network connectivity testing
telnet SERVER_IP 443        # Test TCP connectivity
nc -u -v SERVER_IP 8443     # Test UDP connectivity (if nc available)
```

## Security and Validation Rules

### File Permission Requirements
- `/etc/proxy-server/client-info.txt`: 600 (sensitive client data)
- `/etc/proxy-server/xray/config.json`: 600 (server configuration)
- `/etc/proxy-server/hysteria/config.yaml`: 600 (server configuration)
- All binaries: 755 with root ownership
- Management scripts: 755 (`/usr/local/bin/proxy-manager`, `/usr/local/bin/pm`)

### Input Validation Patterns
- **Port validation**: `^[1-9][0-9]{0,4}$` with range 1-65535
- **Domain validation**: `^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$`
- **Binary integrity**: Check file size > 0 and successful extraction
- **Network operations**: Always validate curl/wget exit codes

### Error Handling Standards
- Exit with code 1 on critical failures
- Display colored error messages using `${RED}` color codes
- Validate service startup status before proceeding
- Auto-retry GitHub API calls if they return null/empty responses

## Protocol Configuration Standards

### Xray REALITY Requirements
- **Flow**: Must use `xtls-rprx-vision` (NOT `xtls-rprx-direct` - deprecated)
- **Key generation**: Use `./xray x25519` command for proper key pairs
- **SNI selection**: Target websites must support TLSv1.3 and H2
- **Default SNI**: `www.microsoft.com` (stable, enterprise-grade)
- **sniffing**: Enable for `http` and `tls` protocols
- **Network**: TCP only with `security: "reality"`

### Hysteria2 Configuration Requirements
- **QUIC settings**: Use optimized window sizes (8388608/20971520)
- **Port**: UDP only (default 8443)
- **Authentication**: Password-based with base64-encoded 32-byte passwords
- **Masquerading**: Proxy to `https://www.bing.com` with `rewriteHost: true`
- **Certificates**: ACME preferred, self-signed fallback with EC P-256 keys
- **Bandwidth**: Default 1000 mbps up/down limits

## Environment Variables and Customization

### Installation Customization
```bash
# Port configuration
REALITY_PORT=8443          # Default: 443 (TCP)
HYSTERIA_PORT=9443         # Default: 8443 (UDP)

# Protocol settings
REALITY_SNI=www.amazon.com # Default: www.microsoft.com
SERVER_IP=1.2.3.4          # Override auto-detection
DOMAIN=example.com         # Enable ACME certificates for Hysteria2

# Usage example
REALITY_PORT=8443 DOMAIN=my-domain.com bash reality-hysteria2.sh install
```

### Configuration File Locations
- **Client connection info**: `/etc/proxy-server/client-info.txt`
- **Xray config**: `/etc/proxy-server/xray/config.json`
- **Hysteria2 config**: `/etc/proxy-server/hysteria/config.yaml`
- **Self-signed certs**: `/etc/proxy-server/certs/` (if no domain specified)
- **Systemd services**: `/etc/systemd/system/{xray-reality,hysteria2}.service`

## Testing and Validation

### Script Testing Procedures
```bash
# Syntax validation
bash -n reality-hysteria2.sh                    # Check syntax without execution

# Test environment variables
echo $REALITY_PORT $HYSTERIA_PORT $DOMAIN       # Verify env vars before installation

# Dry-run validation (manual inspection points)
# 1. Check OS detection logic
# 2. Verify architecture mapping (x86_64->amd64, aarch64->arm64)  
# 3. Validate port input handling
# 4. Test GitHub API connectivity
```

### Post-Installation Validation
```bash
# Verify file structure and permissions
ls -la /etc/proxy-server/
ls -la /usr/local/bin/pm /usr/local/bin/proxy-manager

# Test service functionality
proxy-manager status                             # Should show both services active
proxy-manager info | grep -E "(vless|hysteria2)" # Verify URI generation

# Network binding verification  
ss -tlnp | grep :443                            # REALITY should be listening
ss -ulnp | grep :8443                           # Hysteria2 should be listening

# Configuration integrity
jq . /etc/proxy-server/xray/config.json >/dev/null   # Valid JSON
yq . /etc/proxy-server/hysteria/config.yaml >/dev/null # Valid YAML (if yq available)
```

## Development and Maintenance Notes

### Binary Management
- Downloads use GitHub Releases API: `https://api.github.com/repos/{XTLS/Xray-core,apernet/hysteria}/releases/latest`
- Architecture detection: `uname -m` mapped to `amd64|arm64`
- Verification: Check file size > 0 and successful unzip/chmod operations
- No GPG signature verification (feature gap)

### System Integration
- **Systemd services**: Independent units for xray-reality and hysteria2
- **System optimization**: BBR congestion control, optimized file descriptors
- **Network optimization**: Kernel parameters for TCP/UDP performance
- **Service dependencies**: Properly configured After/Wants in systemd units

### Architecture Patterns
- **No templating**: All configs generated via heredoc and variable substitution
- **Atomic operations**: Full installation or complete rollback
- **Idempotent design**: Can be run multiple times safely
- **Error isolation**: Each major step has independent error handling

### Uninstall Procedure
1. Stop and disable systemd services
2. Remove `/etc/proxy-server/` directory
3. Remove systemd unit files
4. Remove management scripts (`proxy-manager`, `pm`)
5. Clean systemd daemon cache

## Critical Architecture Decisions

### Why No `set -euo pipefail`
- Script is interactive with user input validation loops
- Some commands are expected to fail (e.g., checking existing installations)
- Manual error handling at critical points provides better user experience
- Strict mode would cause unexpected exits during normal operation

### Protocol-Specific Design Choices
- **REALITY SNI**: Uses `www.microsoft.com` for enterprise-grade stability
- **Hysteria2 masquerading**: Proxies to `www.bing.com` for authenticity
- **Certificate strategy**: ACME preferred, self-signed EC P-256 fallback
- **Port defaults**: 443 (TCP) and 8443 (UDP) for common firewall compatibility

### Security Model
- All configuration files use 600 permissions (owner-only access)
- Root ownership required for system service integration
- No credential logging or temporary file exposure
- URI anchor escaping (`\#`) prevents shell interpretation issues

### Service Management Philosophy
- Independent systemd units for protocol isolation
- Complete lifecycle management through `proxy-manager`
- Atomic install/uninstall operations
- Status validation at each deployment step

## Common Issues and Troubleshooting

### Hysteria2 Connection Issues

**Issue**: Client shows "跳过测试" (skip test) or connection failed

**Root Causes and Solutions**:

1. **URI Generation Problems** (Fixed in recent commits):
   - **Problem**: Script was generating URIs with domain in address field but IP needed for connection
   - **Solution**: Client should use IP address for connection, domain for SNI only
   - **Correct format**: `hysteria2://password@IP:8443/?sni=domain.com#tag`
   - **Wrong format**: `hysteria2://password@domain.com:8443/?sni=domain.com#tag`

2. **Escaped Character in URI**:
   - **Problem**: Shell escaping caused `\#` instead of `#` in URIs
   - **Solution**: Remove backslash escape in heredoc: `\#` → `#`

3. **Certificate vs Connection Address Mismatch**:
   - **Server side**: Uses domain for ACME certificates
   - **Client side**: Must connect to IP but use domain for SNI
   - **Key insight**: ACME certificates work with IP connections if SNI matches domain

### Binary Download Failures

**Issue**: "xray 下载失败" during installation

**Root Causes**:
- **Architecture mapping mismatch**: Script mapped `x86_64` → `amd64` but Xray releases use `64`
- **GitHub API dependency**: Required `jq` but should use basic text processing

**Solutions Applied**:
- Fixed architecture mapping: `x86_64` → `64`, `aarch64` → `arm64-v8a`
- Removed `jq` dependency, use `grep | cut` for JSON parsing
- Separate architecture variables for different projects: `XRAY_ARCH` vs `HY_ARCH`

### Architecture-Specific Download URLs

**Xray-core releases**:
- x86_64: `Xray-linux-64.zip`
- aarch64: `Xray-linux-arm64-v8a.zip`

**Hysteria releases**:
- x86_64: `hysteria-linux-amd64`
- aarch64: `hysteria-linux-arm64`

### Client Configuration Best Practices

**v2rayN Hysteria2 Configuration**:
- **地址 (address)**: Use server IP address
- **端口 (port)**: 8443 (UDP)
- **密码 (password)**: Base64-encoded from server
- **SNI**: Use domain name (if ACME enabled)
- **跳过证书验证**: Set to `false` for ACME certificates

**Connection Flow**:
1. Client connects to IP:8443 (UDP)
2. TLS handshake uses SNI=domain.com
3. Server validates with Let's Encrypt certificate
4. QUIC connection established

### Debugging Workflow

1. **Check service status**: `systemctl status xray-reality hysteria2`
2. **Verify ports**: `ss -tlnp | grep 443` and `ss -ulnp | grep 8443`
3. **Monitor connections**: `journalctl -u hysteria2 -f` during client test
4. **Validate certificates**: Check ACME log for successful certificate acquisition
5. **Test connectivity**: Use official Hysteria2 client for verification