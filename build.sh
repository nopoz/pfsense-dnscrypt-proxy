#!/bin/sh
# SPDX-License-Identifier: ISC
# Build script for pfSense-pkg-dnscrypt-proxy
# Creates a FreeBSD .pkg file and optionally deploys to a pfSense instance.
#
# Usage:
#   ./build.sh                  Build the .pkg file locally
#   ./build.sh deploy [host]    Build and install on pfSense (default host: pf)
#   ./build.sh clean            Remove build artifacts
#
# Requirements:
#   - FreeBSD pkg tools (pkg create) on the build machine, OR
#   - deploy mode uses the target pfSense box to run pkg create via SSH

set -e

# --- Configuration ---
PORTNAME="pfSense-pkg-dnscrypt-proxy"
PORTVERSION="${PORTVERSION:-1.0.3}"
PREFIX="/usr/local"
DATADIR="${PREFIX}/share/${PORTNAME}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="${SCRIPT_DIR}/files"
BUILD_DIR="${SCRIPT_DIR}/build"
STAGE_DIR="${BUILD_DIR}/stage"
PKG_OUTPUT_DIR="${BUILD_DIR}/pkg"
PFSENSE_HOST="${DEPLOY_HOST:-pf}"

# --- Functions ---

usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build          Build the .pkg file (default)"
    echo "  deploy [host]  Build and install on pfSense (default host: pf)"
    echo "  clean          Remove build artifacts"
    echo ""
    echo "Environment variables:"
    echo "  DEPLOY_HOST    pfSense SSH host (default: pf)"
    echo "  PORTVERSION    Package version (default: 1.0.3)"
}

clean() {
    echo "Cleaning build artifacts..."
    rm -rf "${STAGE_DIR}"
    rm -rf "${PKG_OUTPUT_DIR}"
    rm -f "${BUILD_DIR}/pkg-install"
    rm -f "${BUILD_DIR}/pkg-deinstall"
    echo "Done."
}

stage_files() {
    echo "Staging files..."
    rm -rf "${STAGE_DIR}"

    # Create directory structure
    mkdir -p "${STAGE_DIR}${PREFIX}/pkg"
    mkdir -p "${STAGE_DIR}${PREFIX}/bin/dnscrypt-proxy-bin"
    mkdir -p "${STAGE_DIR}${PREFIX}/www/shortcuts"
    mkdir -p "${STAGE_DIR}${DATADIR}"
    mkdir -p "${STAGE_DIR}/etc/inc/priv"

    # Install data files
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy.inc" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-advanced.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-cache.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-lists.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-logging.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-querylog.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/pkg/dnscrypt-proxy-servers.xml" \
        "${STAGE_DIR}${PREFIX}/pkg/"
    install -m 0644 "${FILES_DIR}${PREFIX}/share/${PORTNAME}/info.xml" \
        "${STAGE_DIR}${DATADIR}/"
    install -m 0644 "${FILES_DIR}${PREFIX}/www/dnscrypt-proxy-querylog.php" \
        "${STAGE_DIR}${PREFIX}/www/"
    install -m 0644 "${FILES_DIR}${PREFIX}/www/shortcuts/pkg_dnscrypt-proxy.inc" \
        "${STAGE_DIR}${PREFIX}/www/shortcuts/"
    install -m 0644 "${FILES_DIR}/etc/inc/priv/dnscrypt-proxy.priv.inc" \
        "${STAGE_DIR}/etc/inc/priv/"
    install -m 0644 "${FILES_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/LICENSE" \
        "${STAGE_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/"

    # Install program files (executable)
    install -m 0755 "${FILES_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/dnscrypt-proxy-amd64" \
        "${STAGE_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/"
    install -m 0755 "${FILES_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/dnscrypt-proxy-arm64" \
        "${STAGE_DIR}${PREFIX}/bin/dnscrypt-proxy-bin/"

    # Perform version substitution (portable sed - works on BSD and GNU)
    if sed --version >/dev/null 2>&1; then
        # GNU sed (Linux)
        sed -i "s|%%PKGVERSION%%|${PORTVERSION}|g" \
            "${STAGE_DIR}${DATADIR}/info.xml"
    else
        # BSD sed (FreeBSD/macOS)
        sed -i '' "s|%%PKGVERSION%%|${PORTVERSION}|g" \
            "${STAGE_DIR}${DATADIR}/info.xml"
    fi

    # Generate install/deinstall scripts from templates
    sed "s|%%PORTNAME%%|${PORTNAME}|g" \
        "${FILES_DIR}/pkg-install.in" > "${BUILD_DIR}/pkg-install"
    sed "s|%%PORTNAME%%|${PORTNAME}|g" \
        "${FILES_DIR}/pkg-deinstall.in" > "${BUILD_DIR}/pkg-deinstall"
    chmod 0755 "${BUILD_DIR}/pkg-install" "${BUILD_DIR}/pkg-deinstall"

    echo "Staged $(find "${STAGE_DIR}" -type f | wc -l | tr -d ' ') files."
}

generate_manifest() {
    echo "Generating package manifest..."

    # Detect architecture
    ARCH=$(uname -p)

    # UCL manifest for pkg create
    # Note: We use a wildcard ABI to support both pfSense CE (FreeBSD 15) and
    # pfSense Plus (FreeBSD 16). This works because dnscrypt-proxy is a
    # statically-linked Go binary with no libc dependencies.
    cat > "${BUILD_DIR}/+MANIFEST" <<EOF
name: "${PORTNAME}"
version: "${PORTVERSION}"
origin: "dns/${PORTNAME}"
comment: "pfSense package for DNSCrypt Proxy encrypted DNS client"
maintainer: "ports@FreeBSD.org"
prefix: "${PREFIX}"
abi: "FreeBSD:*:*"
desc: "pfSense package for DNSCrypt Proxy, an encrypted DNS client supporting DNSCrypt v2 and DNS-over-HTTPS protocols."
www: "https://github.com/DNSCrypt/dnscrypt-proxy"
licenselogic: "single"
licenses: ["ISC"]
categories: ["dns"]
EOF

    # Generate the plist
    cat > "${BUILD_DIR}/plist" <<'PLIST'
/etc/inc/priv/dnscrypt-proxy.priv.inc
bin/dnscrypt-proxy-bin/LICENSE
bin/dnscrypt-proxy-bin/dnscrypt-proxy-amd64
bin/dnscrypt-proxy-bin/dnscrypt-proxy-arm64
pkg/dnscrypt-proxy.inc
pkg/dnscrypt-proxy.xml
pkg/dnscrypt-proxy-advanced.xml
pkg/dnscrypt-proxy-cache.xml
pkg/dnscrypt-proxy-lists.xml
pkg/dnscrypt-proxy-logging.xml
pkg/dnscrypt-proxy-querylog.xml
pkg/dnscrypt-proxy-servers.xml
share/pfSense-pkg-dnscrypt-proxy/info.xml
www/dnscrypt-proxy-querylog.php
www/shortcuts/pkg_dnscrypt-proxy.inc
@dir bin/dnscrypt-proxy-bin
@dir /etc/inc/priv
@dir /etc/inc
PLIST
}

build_pkg() {
    stage_files
    generate_manifest

    mkdir -p "${PKG_OUTPUT_DIR}"

    echo "Building package..."

    # Try local pkg create first
    if command -v pkg >/dev/null 2>&1; then
        pkg create \
            -M "${BUILD_DIR}/+MANIFEST" \
            -p "${BUILD_DIR}/plist" \
            -r "${STAGE_DIR}" \
            -o "${PKG_OUTPUT_DIR}" \
            --format txz 2>/dev/null || \
        pkg create \
            -M "${BUILD_DIR}/+MANIFEST" \
            -p "${BUILD_DIR}/plist" \
            -r "${STAGE_DIR}" \
            -o "${PKG_OUTPUT_DIR}"

        PKG_FILE=$(find "${PKG_OUTPUT_DIR}" -name "${PORTNAME}*" -type f | head -1)
        echo ""
        echo "Package built: ${PKG_FILE}"
        echo "Size: $(ls -lh "${PKG_FILE}" | awk '{print $5}')"
    else
        echo ""
        echo "pkg tools not found locally."
        echo "Run './build.sh deploy' to build and install on pfSense directly."
        return 1
    fi
}

deploy() {
    HOST="${1:-${PFSENSE_HOST}}"

    echo "Deploying to ${HOST}..."

    # Verify SSH connectivity
    if ! ssh -o ConnectTimeout=5 "${HOST}" "echo ok" >/dev/null 2>&1; then
        echo "Error: Cannot connect to ${HOST} via SSH."
        echo "Set DEPLOY_HOST or pass the hostname: ./build.sh deploy <host>"
        exit 1
    fi

    stage_files
    generate_manifest

    # Create remote build directory
    REMOTE_DIR="/tmp/${PORTNAME}-build"
    ssh "${HOST}" "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}/stage"

    echo "Uploading staged files..."
    tar -cf - -C "${STAGE_DIR}" . | ssh "${HOST}" "tar -xf - -C ${REMOTE_DIR}/stage"

    # Upload manifest, plist, and scripts
    scp -q "${BUILD_DIR}/+MANIFEST" "${HOST}:${REMOTE_DIR}/"
    scp -q "${BUILD_DIR}/plist" "${HOST}:${REMOTE_DIR}/"
    scp -q "${BUILD_DIR}/pkg-install" "${HOST}:${REMOTE_DIR}/"
    scp -q "${BUILD_DIR}/pkg-deinstall" "${HOST}:${REMOTE_DIR}/"

    echo "Building package on ${HOST}..."
    PKG_FILE=$(ssh "${HOST}" <<REMOTE
set -e

cd ${REMOTE_DIR}

pkg create \
    -M ${REMOTE_DIR}/+MANIFEST \
    -p ${REMOTE_DIR}/plist \
    -r ${REMOTE_DIR}/stage \
    -o ${REMOTE_DIR}/ 2>&1

PKG_FILE=\$(ls ${REMOTE_DIR}/${PORTNAME}-*.pkg 2>/dev/null | head -1)
if [ -z "\${PKG_FILE}" ]; then
    PKG_FILE=\$(ls ${REMOTE_DIR}/${PORTNAME}-*.txz 2>/dev/null | head -1)
fi

echo "\${PKG_FILE}"
REMOTE
    )

    PKG_FILE=$(echo "${PKG_FILE}" | tail -1)

    if [ -z "${PKG_FILE}" ]; then
        echo "Error: Package build failed on ${HOST}."
        exit 1
    fi

    echo "Package built: ${PKG_FILE}"

    echo "Installing package..."
    ssh "${HOST}" <<REMOTE
set -e

if pkg info ${PORTNAME} >/dev/null 2>&1; then
    echo "Removing existing ${PORTNAME}..."
    pkg delete -y ${PORTNAME}
fi

pkg add -f ${PKG_FILE}

echo "Running post-install..."
/usr/local/bin/php -f /etc/rc.packages ${PORTNAME} POST-INSTALL || true

rm -rf ${REMOTE_DIR}

echo ""
echo "Package ${PORTNAME}-${PORTVERSION} installed successfully."
pkg info ${PORTNAME}
REMOTE
}

# --- Main ---

COMMAND="${1:-build}"

case "${COMMAND}" in
    build)
        build_pkg
        ;;
    deploy)
        deploy "${2}"
        ;;
    clean)
        clean
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown command: ${COMMAND}"
        usage
        exit 1
        ;;
esac
