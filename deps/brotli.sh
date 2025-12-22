#!/usr/bin/env bash
# Build brotli (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# Brotli is a compression library used by Nix's libutil.
# Nix requires all three components: brotlicommon, brotlidec, brotlienc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="brotli"
VERSION="1.1.0"
URL="https://github.com/google/brotli/archive/refs/tags/v${VERSION}.tar.gz"

build_brotli() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_cmake "$src_dir" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBROTLI_DISABLE_TESTS=ON
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_brotli
