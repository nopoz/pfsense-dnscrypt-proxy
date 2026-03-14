#!/bin/sh
# SPDX-License-Identifier: ISC
# Bump the package version in all files that track it.
#
# Usage:
#   ./bump-version.sh 1.3.0

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo ""
    echo "Current version: $(grep '^version:' build/+MANIFEST | awk '{print $2}' | tr -d '"')"
    exit 1
fi

NEW_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# build/+MANIFEST
sed -i "s/^version: \".*\"/version: \"${NEW_VERSION}\"/" "${SCRIPT_DIR}/build/+MANIFEST"

# Makefile
sed -i "s/^PORTVERSION=.*/PORTVERSION=\t${NEW_VERSION}/" "${SCRIPT_DIR}/Makefile"

echo "Bumped version to ${NEW_VERSION}"
echo ""
echo "Updated files:"
grep -n "version\|PORTVERSION" "${SCRIPT_DIR}/build/+MANIFEST" "${SCRIPT_DIR}/Makefile"
