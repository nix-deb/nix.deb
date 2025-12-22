#!/usr/bin/env bash
# Build OpenSSL (Tier 1 - depends on zlib)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="openssl"
VERSION="3.4.1"
URL="https://github.com/openssl/openssl/releases/download/openssl-${VERSION}/openssl-${VERSION}.tar.gz"

build_openssl() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    cd "$src_dir"

    # OpenSSL has its own configure system
    # Key options:
    #   no-shared       - build static libraries only
    #   no-engine       - disable engine support (avoids dlopen)
    #   no-dso          - disable dynamic shared objects
    #   no-legacy       - disable legacy algorithms (smaller binary)
    #   no-tests        - skip building tests

    local target
    case "$TARGET_ARCH" in
        x86_64)  target="linux-x86_64-clang" ;;
        aarch64) target="linux-aarch64" ;;
        *)       die "Unsupported architecture: $TARGET_ARCH" ;;
    esac

    CC="$CC" \
    CXX="$CXX" \
    ./Configure "$target" \
        --prefix="$PREFIX" \
        --openssldir="$PREFIX/ssl" \
        --with-zlib-include="$PREFIX/include" \
        --with-zlib-lib="$PREFIX/lib" \
        no-shared \
        no-engine \
        no-dso \
        no-legacy \
        no-tests \
        no-docs \
        zlib \
        $CFLAGS

    pmake
    make install_sw  # install_sw skips docs
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_openssl
