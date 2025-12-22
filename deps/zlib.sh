#!/usr/bin/env bash
# Build zlib (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="zlib"
VERSION="1.3.1"
URL="https://github.com/madler/zlib/releases/download/v${VERSION}/zlib-${VERSION}.tar.gz"

build_zlib() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    cd "$src_dir"

    # zlib uses a custom configure script, not autoconf
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    ./configure \
        --prefix="$PREFIX" \
        --static

    pmake
    make install
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_zlib
