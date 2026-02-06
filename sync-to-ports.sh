#!/bin/sh
# SPDX-License-Identifier: ISC
# Sync standalone repo to FreeBSD-ports fork for PR maintenance
#
# This script copies package files from the standalone repo to the
# FreeBSD-ports fork, keeping the PR branch in sync.
#
# Usage:
#   ./sync-to-ports.sh                    Sync files only
#   ./sync-to-ports.sh --commit           Sync and commit changes
#   ./sync-to-ports.sh --commit --push    Sync, commit, and push
#
# Configuration:
#   Set PORTS_DIR environment variable to override the default path

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORTS_DIR="${PORTS_DIR:-/mnt/c/Users/plaid/FreeBSD-ports}"
PKG_SUBDIR="dns/pfSense-pkg-dnscrypt-proxy"
TARGET_DIR="${PORTS_DIR}/${PKG_SUBDIR}"

DO_COMMIT=false
DO_PUSH=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --commit)
            DO_COMMIT=true
            ;;
        --push)
            DO_PUSH=true
            ;;
        --help|-h)
            echo "Usage: $0 [--commit] [--push]"
            echo ""
            echo "Syncs package files from standalone repo to FreeBSD-ports fork."
            echo ""
            echo "Options:"
            echo "  --commit    Commit changes to the ports repo after syncing"
            echo "  --push      Push changes to remote (implies --commit)"
            echo ""
            echo "Environment:"
            echo "  PORTS_DIR   Path to FreeBSD-ports fork (default: ${PORTS_DIR})"
            exit 0
            ;;
    esac
done

if [ "$DO_PUSH" = true ]; then
    DO_COMMIT=true
fi

# --- Validation ---
if [ ! -d "${PORTS_DIR}" ]; then
    echo "Error: FreeBSD-ports directory not found: ${PORTS_DIR}"
    echo "Set PORTS_DIR environment variable to the correct path."
    exit 1
fi

if [ ! -d "${PORTS_DIR}/.git" ]; then
    echo "Error: ${PORTS_DIR} is not a git repository."
    exit 1
fi

echo "=== Syncing to FreeBSD-ports fork ==="
echo "Source:      ${SCRIPT_DIR}"
echo "Destination: ${TARGET_DIR}"
echo ""

# --- Create target directory if needed ---
mkdir -p "${TARGET_DIR}"

# --- Sync files ---
echo "Syncing files..."

# Copy files directory
if [ -d "${SCRIPT_DIR}/files" ]; then
    rm -rf "${TARGET_DIR}/files"
    cp -r "${SCRIPT_DIR}/files" "${TARGET_DIR}/"
    echo "  files/ -> synced"
fi

# Copy Makefile
if [ -f "${SCRIPT_DIR}/Makefile" ]; then
    cp "${SCRIPT_DIR}/Makefile" "${TARGET_DIR}/"
    echo "  Makefile -> synced"
fi

# Copy pkg-descr
if [ -f "${SCRIPT_DIR}/pkg-descr" ]; then
    cp "${SCRIPT_DIR}/pkg-descr" "${TARGET_DIR}/"
    echo "  pkg-descr -> synced"
fi

# Copy pkg-plist
if [ -f "${SCRIPT_DIR}/pkg-plist" ]; then
    cp "${SCRIPT_DIR}/pkg-plist" "${TARGET_DIR}/"
    echo "  pkg-plist -> synced"
fi

# Sync build directory (excluding generated artifacts)
mkdir -p "${TARGET_DIR}/build"
if [ -f "${SCRIPT_DIR}/build/+MANIFEST" ]; then
    cp "${SCRIPT_DIR}/build/+MANIFEST" "${TARGET_DIR}/build/"
    echo "  build/+MANIFEST -> synced"
fi
if [ -f "${SCRIPT_DIR}/build/plist" ]; then
    cp "${SCRIPT_DIR}/build/plist" "${TARGET_DIR}/build/"
    echo "  build/plist -> synced"
fi

# Sync stage directory if present
if [ -d "${SCRIPT_DIR}/build/stage" ]; then
    rm -rf "${TARGET_DIR}/build/stage"
    cp -r "${SCRIPT_DIR}/build/stage" "${TARGET_DIR}/build/"
    echo "  build/stage/ -> synced"
fi

echo ""
echo "Sync complete."

# --- Git operations ---
if [ "$DO_COMMIT" = true ]; then
    echo ""
    echo "=== Committing changes ==="

    cd "${PORTS_DIR}"

    # Check if on correct branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "${CURRENT_BRANCH}" != "dnscrypt" ]; then
        echo "Warning: Currently on branch '${CURRENT_BRANCH}', not 'dnscrypt'"
        echo "Switch to the correct branch before committing."
        exit 1
    fi

    # Stage changes
    git add "${PKG_SUBDIR}"

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo "No changes to commit."
    else
        # Get version from manifest if available
        VERSION=$(grep '^version:' "${TARGET_DIR}/build/+MANIFEST" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")

        if [ -n "${VERSION}" ]; then
            COMMIT_MSG="Update DNSCrypt Proxy package to v${VERSION}"
        else
            COMMIT_MSG="Update DNSCrypt Proxy package"
        fi

        git commit -m "${COMMIT_MSG}

Synced from standalone repository."

        echo "Committed: ${COMMIT_MSG}"
    fi

    if [ "$DO_PUSH" = true ]; then
        echo ""
        echo "=== Pushing to remote ==="
        git push origin "${CURRENT_BRANCH}"
        echo "Pushed to origin/${CURRENT_BRANCH}"
    fi
fi

echo ""
echo "Done."
