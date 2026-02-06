#!/bin/sh
# SPDX-License-Identifier: ISC
# Completely uninstall DNSCrypt Proxy from a pfSense instance.
# Removes all package files, runtime files, and pfSense registrations.
# Preserves user settings in config.xml so they survive reinstall.
#
# Use this script when:
#   - Normal 'pkg delete' doesn't fully clean up
#   - You need a clean slate before reinstalling
#   - Troubleshooting package issues
#
# Usage:
#   ./uninstall.sh [host]    Uninstall from pfSense (default host: pf)
#
# Environment variables:
#   DEPLOY_HOST    pfSense SSH host (default: pf)

set -e

PORTNAME="pfSense-pkg-dnscrypt-proxy"
HOST="${1:-${DEPLOY_HOST:-pf}}"

echo "Cleaning ${PORTNAME} from ${HOST}..."
echo ""

# Verify SSH connectivity
if ! ssh -o ConnectTimeout=5 "${HOST}" "echo ok" >/dev/null 2>&1; then
    echo "Error: Cannot connect to ${HOST} via SSH."
    exit 1
fi

ssh "${HOST}" <<'REMOTE'
set -e

PORTNAME="pfSense-pkg-dnscrypt-proxy"

echo "=== Step 1: Stop dnscrypt-proxy if running ==="
if pgrep -q dnscrypt-proxy 2>/dev/null; then
    echo "Stopping dnscrypt-proxy..."
    killall -q dnscrypt-proxy || true
    sleep 1
    # Force kill if still running
    killall -q -9 dnscrypt-proxy 2>/dev/null || true
    echo "Stopped."
else
    echo "Not running."
fi

echo ""
echo "=== Step 2: Remove pkg registration (if installed via pkg) ==="
if pkg info "${PORTNAME}" >/dev/null 2>&1; then
    echo "Removing package registration..."
    pkg delete -y "${PORTNAME}" 2>/dev/null || true
    echo "Removed."
else
    echo "Not registered as a pkg."
fi

echo ""
echo "=== Step 3: Remove package registration from config.xml ==="
echo "  (Preserving user settings in installedpackages/dnscryptproxy)"
/usr/local/bin/php -r '
require_once("config.inc");
require_once("util.inc");

$changed = false;

/* Remove the package entry */
$packages = config_get_path("installedpackages/package", []);
foreach ($packages as $idx => $pkg) {
    if (isset($pkg["internal_name"]) && $pkg["internal_name"] == "dnscrypt-proxy" ||
        isset($pkg["name"]) && (
            $pkg["name"] == "pfSense-pkg-dnscrypt-proxy" ||
            $pkg["name"] == "DNSCrypt Proxy" ||
            stripos($pkg["name"], "dnscrypt") !== false
        )) {
        unset($packages[$idx]);
        $changed = true;
    }
}
if ($changed) {
    config_set_path("installedpackages/package", array_values($packages));
    echo "  Removed package entry.\n";
}

/* Remove menu entries */
$menus = config_get_path("installedpackages/menu", []);
$filtered = [];
foreach ($menus as $menu) {
    if (isset($menu["name"]) && stripos($menu["name"], "dnscrypt") !== false) {
        $changed = true;
        echo "  Removed menu entry: " . $menu["name"] . "\n";
    } else {
        $filtered[] = $menu;
    }
}
config_set_path("installedpackages/menu", $filtered);

/* Remove service entries */
$services = config_get_path("installedpackages/service", []);
$filtered = [];
foreach ($services as $svc) {
    if (isset($svc["name"]) && stripos($svc["name"], "dnscrypt") !== false) {
        $changed = true;
        echo "  Removed service entry: " . $svc["name"] . "\n";
    } else {
        $filtered[] = $svc;
    }
}
config_set_path("installedpackages/service", $filtered);

if ($changed) {
    write_config("[dnscrypt-proxy] Removed package, menu, and service registrations for clean reinstall");
    echo "Config.xml registrations removed.\n";
} else {
    echo "No registrations found in config.xml.\n";
}
'
echo "User settings preserved."

echo ""
echo "=== Step 4: Remove installed package files ==="

# Package files (from pkg-plist / Makefile)
rm -f /usr/local/pkg/dnscrypt-proxy.inc
rm -f /usr/local/pkg/dnscrypt-proxy.xml
rm -f /usr/local/pkg/dnscrypt-proxy-advanced.xml
rm -f /usr/local/pkg/dnscrypt-proxy-cache.xml
rm -f /usr/local/pkg/dnscrypt-proxy-lists.xml
rm -f /usr/local/pkg/dnscrypt-proxy-logging.xml
rm -f /usr/local/pkg/dnscrypt-proxy-querylog.xml
rm -f /usr/local/pkg/dnscrypt-proxy-servers.xml
rm -f /usr/local/share/pfSense-pkg-dnscrypt-proxy/info.xml
rm -f /usr/local/www/dnscrypt-proxy-querylog.php
rm -f /usr/local/www/shortcuts/pkg_dnscrypt-proxy.inc
rm -f /etc/inc/priv/dnscrypt-proxy.priv.inc
rm -f /usr/local/bin/dnscrypt-proxy-bin/LICENSE
rm -f /usr/local/bin/dnscrypt-proxy-bin/dnscrypt-proxy-amd64
rm -f /usr/local/bin/dnscrypt-proxy-bin/dnscrypt-proxy-arm64
echo "Package files removed."

echo ""
echo "=== Step 5: Remove runtime files ==="

# Binary symlink/copy created by dnscrypt_proxy_install_binary()
rm -f /usr/local/bin/dnscrypt-proxy

# RC startup script (including any renamed/backup copies)
rm -f /usr/local/etc/rc.d/dnscrypt-proxy.sh
rm -f /usr/local/etc/rc.d/dnscrypt-proxy.sh_old
rm -f /usr/local/etc/rc.d/dnscrypt-proxy.sh.bak

# Generated config files
rm -f /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml
rm -f /usr/local/etc/dnscrypt-proxy/blocked-names.txt
rm -f /usr/local/etc/dnscrypt-proxy/allowed-names.txt
rm -f /usr/local/etc/dnscrypt-proxy/forwarding-rules.txt
rm -f /usr/local/etc/dnscrypt-proxy/cloaking-rules.txt

# PID file
rm -f /var/run/dnscrypt_proxy.pid

# Log files
rm -rf /var/log/dnscrypt-proxy

# Cache files
rm -rf /var/cache/dnscrypt-proxy

echo "Runtime files removed."

echo ""
echo "=== Step 6: Remove empty directories ==="
rmdir /usr/local/bin/dnscrypt-proxy-bin 2>/dev/null || true
rmdir /usr/local/etc/dnscrypt-proxy 2>/dev/null || true
rmdir /usr/local/share/pfSense-pkg-dnscrypt-proxy 2>/dev/null || true
echo "Done."

echo ""
echo "=== Step 7: Verify clean state ==="
LEFTOVER=0

for f in \
    /usr/local/pkg/dnscrypt-proxy.inc \
    /usr/local/pkg/dnscrypt-proxy.xml \
    /usr/local/bin/dnscrypt-proxy \
    /usr/local/bin/dnscrypt-proxy-bin/dnscrypt-proxy-amd64 \
    /usr/local/etc/rc.d/dnscrypt-proxy.sh \
    /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml \
    /usr/local/www/dnscrypt-proxy-querylog.php \
    /etc/inc/priv/dnscrypt-proxy.priv.inc \
    /var/run/dnscrypt_proxy.pid; do
    if [ -e "$f" ]; then
        echo "WARNING: leftover file: $f"
        LEFTOVER=1
    fi
done

for d in \
    /usr/local/bin/dnscrypt-proxy-bin \
    /usr/local/etc/dnscrypt-proxy \
    /var/log/dnscrypt-proxy \
    /var/cache/dnscrypt-proxy; do
    if [ -d "$d" ]; then
        echo "WARNING: leftover directory: $d"
        LEFTOVER=1
    fi
done

if pgrep -q dnscrypt-proxy 2>/dev/null; then
    echo "WARNING: dnscrypt-proxy process still running"
    LEFTOVER=1
fi

if [ "$LEFTOVER" -eq 0 ]; then
    echo "Clean. No leftover files or processes found."
else
    echo ""
    echo "Some leftovers remain - review warnings above."
fi

echo ""
echo "=== Step 8: Restart webConfigurator ==="
echo "Clearing cached menu and service entries..."
/etc/rc.restart_webgui
echo "webConfigurator restarted."

echo ""
echo "=== Config status ==="
echo "pfSense config.xml settings have been PRESERVED."
echo "Your saved options will be restored on next install."
REMOTE

echo ""
echo "Clean complete. Run './build.sh deploy ${HOST}' to reinstall."
