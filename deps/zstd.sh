#!/usr/bin/env bash
# Build zstd (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="zstd"
VERSION="1.5.7"
URL="https://github.com/facebook/zstd/releases/download/v${VERSION}/zstd-${VERSION}.tar.gz"

build_zstd() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    # zstd uses CMake for the library build
    build_cmake "$src_dir/build/cmake" \
        -DZSTD_BUILD_PROGRAMS=OFF \
        -DZSTD_BUILD_CONTRIB=OFF \
        -DZSTD_BUILD_TESTS=OFF \
        -DZSTD_BUILD_STATIC=ON \
        -DZSTD_BUILD_SHARED=OFF
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_zstd
