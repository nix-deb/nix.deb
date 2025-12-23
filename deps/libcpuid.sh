#!/usr/bin/env bash
# Build libcpuid (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# libcpuid provides CPU feature detection for Nix's libutil.
# It's optional but enables CPU-specific optimizations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="libcpuid"
VERSION="0.7.0"
URL="https://github.com/anrieff/libcpuid/archive/refs/tags/v${VERSION}.tar.gz"

build_libcpuid() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_cmake "$src_dir" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBCPUID_TESTS=OFF
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_libcpuid
