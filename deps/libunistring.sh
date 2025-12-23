#!/usr/bin/env bash
# Build libunistring (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# libunistring provides Unicode string functions.
# Needed by libidn2 for internationalized domain name support.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="libunistring"
VERSION="1.3"
URL="https://ftp.gnu.org/gnu/libunistring/libunistring-${VERSION}.tar.gz"

build_libunistring() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_autoconf "$src_dir" \
        --disable-dependency-tracking
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_libunistring
