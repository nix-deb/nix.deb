#!/usr/bin/env bash
# Build xz/liblzma (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="xz"
VERSION="5.6.4"
URL="https://github.com/tukaani-project/xz/releases/download/v${VERSION}/xz-${VERSION}.tar.xz"

build_xz() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL" "xz-${VERSION}.tar.xz")

    build_autoconf "$src_dir" \
        --disable-xz \
        --disable-xzdec \
        --disable-lzmadec \
        --disable-lzmainfo \
        --disable-scripts \
        --disable-doc \
        --disable-nls
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_xz
