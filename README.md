# pfSense DNSCrypt Proxy Package

A pfSense package providing a full GUI for [DNSCrypt Proxy](https://github.com/DNSCrypt/dnscrypt-proxy), an encrypted DNS client supporting DNSCrypt v2 and DNS-over-HTTPS (DoH) protocols.

> **Note:** This is a community-maintained package and is not affiliated with or supported by Netgate.

## Installation

### pfSense CE 2.7.x

Run this command in the pfSense shell (via SSH or Console):

```bash
pkg-static add https://github.com/nopoz/pfsense-dnscrypt-proxy/releases/latest/download/pfSense-pkg-dnscrypt-proxy.pkg
```

### pfSense Plus

```bash
pkg-static -C /dev/null add https://github.com/nopoz/pfsense-dnscrypt-proxy/releases/latest/download/pfSense-pkg-dnscrypt-proxy.pkg
```

After installation, navigate to **Services > DNSCrypt Proxy** in the pfSense web interface.

### Uninstall

```bash
pkg delete pfSense-pkg-dnscrypt-proxy
```

### Complete Removal (Troubleshooting)

If normal uninstall doesn't fully clean up, or you need a fresh start:

```bash
# From your local machine (requires SSH access to pfSense)
./uninstall.sh pfsense.local
```

This removes all package files, runtime artifacts, and pfSense registrations while preserving your settings in config.xml.

## Features

- **Full GUI Configuration** - 7 configuration tabs accessible from the pfSense web interface
- **Multiple Protocols** - Supports DNSCrypt v2, DNS-over-HTTPS (DoH), and Anonymized DNS
- **Popular Providers** - Pre-configured servers from Cloudflare, Quad9, Google, AdGuard, NextDNS, Mullvad, OpenDNS, CleanBrowsing, and more
- **Custom Resolvers** - Add custom servers via DNS stamps
- **Domain Filtering** - Block and allow lists, forwarding rules, and cloaking
- **Query Logging** - Built-in query log viewer with filtering
- **Multi-Architecture** - Supports both amd64 and arm64 (auto-detected)
- **Service Integration** - Managed via Status > Services like native pfSense services

## Screenshots

<details>
<summary>Click to expand screenshots</summary>

### General Settings
![General Settings](https://github.com/user-attachments/assets/27be86ed-8926-429b-a059-7ac20914303b)

### Server Selection
![Server Selection](https://github.com/user-attachments/assets/5a7c2c95-c3f5-45d3-88f0-ed8a30c6f646)

### Cache & Filtering
![Cache Filtering](https://github.com/user-attachments/assets/8e6a3a71-6cc5-4b5e-bbef-f38f8f9d8f59)

### Logging
![Logging](https://github.com/user-attachments/assets/f1d52162-20db-4d82-87db-a966b2805012)

### Advanced
![Advanced](https://github.com/user-attachments/assets/54730fac-da7a-43c7-afb6-36e4ae6d9da5)

### Query Log
![Query Log](https://github.com/user-attachments/assets/c69d180c-50d4-4615-a7e2-e4e88c55bbfe)

</details>

## Configuration Guide

### Basic Setup

1. Install the package using the command above
2. Navigate to **Services > DNSCrypt Proxy**
3. Check **Enable DNSCrypt Proxy**
4. Select your preferred DNS servers from the **Server Selection** tab
5. Click **Save**
6. Configure pfSense to use DNSCrypt Proxy:
   - Go to **System > General Setup**
   - Set DNS Server to `127.0.0.1` with port `5353` (or your configured port)

### Using with pfSense DNS Resolver (Unbound)

To use DNSCrypt Proxy as an upstream for Unbound:

1. Go to **Services > DNS Resolver > General Settings**
2. Add the following to **Custom options**:

```
server:
    do-not-query-localhost: no
forward-zone:
    name: "."
    forward-addr: 127.0.0.1@5300
```

## Building from Source

Requirements: FreeBSD with `pkg` tools, or a pfSense instance for remote builds.

```bash
# Clone the repository
git clone https://github.com/nopoz/pfsense-dnscrypt-proxy.git
cd pfsense-dnscrypt-proxy

# Build the package (requires FreeBSD)
./build.sh build

# Or build and deploy directly to pfSense via SSH
./build.sh deploy pfsense.local

# Clean build artifacts
./build.sh clean
```

### Available Scripts

| Script | Purpose |
|--------|---------|
| `build.sh build` | Build .pkg file (requires FreeBSD) |
| `build.sh deploy [host]` | Build on pfSense via SSH and install |
| `build.sh clean` | Remove local build artifacts |
| `uninstall.sh [host]` | Completely remove package from pfSense |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOY_HOST` | `pf` | SSH hostname for pfSense |
| `PORTVERSION` | `1.0.0` | Package version to build |

## Upstream PR

This package is also submitted to the official pfSense FreeBSD-ports repository:
- [PR #1434: New Package: DNSCrypt Proxy](https://github.com/pfsense/FreeBSD-ports/pull/1434)

## Related

- [DNSCrypt Proxy](https://github.com/DNSCrypt/dnscrypt-proxy) - The upstream project
- [pfSense Redmine #9315](https://redmine.pfsense.org/issues/9315) - Original feature request

## License

ISC License - See [LICENSE](LICENSE) for details.
