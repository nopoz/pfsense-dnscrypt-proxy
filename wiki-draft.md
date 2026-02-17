# Installation on pfSense

There are two ways to install DNSCrypt Proxy on pfSense:

1. **[GUI Package (Recommended)](#gui-package-recommended)** - Full web interface integration with point-and-click configuration
2. **[Manual Installation](#manual-installation)** - Traditional command-line setup for advanced users

---

## GUI Package (Recommended)

A community-maintained pfSense package provides full GUI integration for DNSCrypt Proxy, accessible from the pfSense web interface at **Services > DNSCrypt Proxy**.

### Features

- Full GUI configuration with 7 tabs (General, Server Selection, Cache & Filtering, Logging, Advanced, Query Log, and more)
- Pre-configured servers from Cloudflare, Quad9, Google, AdGuard, NextDNS, Mullvad, OpenDNS, CleanBrowsing, and others
- Support for DNSCrypt v2, DNS-over-HTTPS (DoH), and Anonymized DNS
- Custom resolver support via DNS stamps
- Domain filtering with block/allow lists, forwarding rules, and cloaking
- Built-in query log viewer with filtering
- Multi-architecture support (amd64 and arm64, auto-detected)
- Native service integration via Status > Services

### Installation

Run one of these commands in the pfSense shell (via SSH or Console):

**pfSense CE:**
```bash
pkg-static add https://github.com/nopoz/pfsense-dnscrypt-proxy/releases/latest/download/pfSense-pkg-dnscrypt-proxy.pkg
```

**pfSense Plus:**
```bash
pkg-static -C /dev/null add https://github.com/nopoz/pfsense-dnscrypt-proxy/releases/latest/download/pfSense-pkg-dnscrypt-proxy.pkg
```

After installation, navigate to **Services > DNSCrypt Proxy** in the pfSense web interface.

### Basic Setup

1. Navigate to **Services > DNSCrypt Proxy**
2. Check **Enable DNSCrypt Proxy**
3. Select your preferred DNS servers from the **Server Selection** tab
4. Click **Save**

### Integrating with DNS Resolver (Unbound)

To forward Unbound queries through DNSCrypt Proxy:

1. Go to **Services > DNS Resolver > General Settings**
2. Add the following to **Custom options**:

```
server:
    do-not-query-localhost: no
forward-zone:
    name: "."
    forward-addr: 127.0.0.1@5300
```

3. Click **Save** and **Apply Changes**

### Uninstall

```bash
pkg delete pfSense-pkg-dnscrypt-proxy
```

For more details, see the [package repository](https://github.com/nopoz/pfsense-dnscrypt-proxy).

---

## Manual Installation

For users who prefer command-line configuration or need custom setups, follow these steps.

### 1. Download and Install the Binary

Download the latest release for FreeBSD/amd64 from the [releases page](https://github.com/DNSCrypt/dnscrypt-proxy/releases):

```bash
cd /tmp
fetch https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.5/dnscrypt-proxy-freebsd_amd64-2.1.5.tar.gz
mkdir dnscrypt-proxy
tar -xzf dnscrypt-proxy-freebsd_amd64-2.1.5.tar.gz -C dnscrypt-proxy
mv dnscrypt-proxy/freebsd-amd64/dnscrypt-proxy /usr/local/bin/
chown root:wheel /usr/local/bin/dnscrypt-proxy
chmod 755 /usr/local/bin/dnscrypt-proxy
```

### 2. Configure DNSCrypt Proxy

Create the configuration directory and copy the example configuration:

```bash
mkdir -p /usr/local/etc/dnscrypt-proxy
cp /tmp/dnscrypt-proxy/freebsd-amd64/example-dnscrypt-proxy.toml /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

Edit the configuration file:

```bash
vi /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

**Important:** Set the listen address to avoid conflicts with pfSense DNS services:

```toml
listen_addresses = ['127.0.0.1:5300']
```

### 3. Create the Startup Script

Create an rc.d script to enable automatic startup:

```bash
cat > /usr/local/etc/rc.d/dnscrypt-proxy.sh << 'EOF'
#!/bin/sh

# PROVIDE: dnscrypt_proxy
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="dnscrypt_proxy"
rcvar="dnscrypt_proxy_enable"

load_rc_config $name

: ${dnscrypt_proxy_enable:="YES"}

pidfile="/var/run/dnscrypt-proxy.pid"
command="/usr/local/bin/dnscrypt-proxy"
command_args="-config /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml -pidfile ${pidfile} -syslog"

run_rc_command "$1"
EOF

chmod +x /usr/local/etc/rc.d/dnscrypt-proxy.sh
```

### 4. Start the Service

```bash
service dnscrypt-proxy.sh start
```

### 5. Configure DNS Resolver (Unbound)

1. Navigate to **Services > DNS Resolver > General Settings**
2. Add the following to **Custom options**:

```
server:
    do-not-query-localhost: no
forward-zone:
    name: "."
    forward-addr: 127.0.0.1@5300
```

3. Click **Save** and **Apply Changes**

---

## Related Links

- [DNSCrypt Proxy GitHub](https://github.com/DNSCrypt/dnscrypt-proxy)
- [GUI Package Repository](https://github.com/nopoz/pfsense-dnscrypt-proxy)
- [Configuration Documentation](https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Configuration)
