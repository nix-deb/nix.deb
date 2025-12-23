#!/usr/bin/env bash
# Build libblake3 (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# libblake3 provides BLAKE3 hashing for Nix's libutil.
# Auto-detects amd64-asm optimizations for x86_64.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="BLAKE3"
VERSION="1.8.2"
URL="https://github.com/BLAKE3-team/BLAKE3/archive/refs/tags/${VERSION}.tar.gz"

build_libblake3() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    # BLAKE3 C implementation is in the c/ subdirectory
    # Auto-detects amd64-asm SIMD optimizations for x86_64
    # Disable oneTBB parallelism (we don't need the dependency)
    # CMake requires C++ even though we don't use it
    # Tell clang++ to use libc++ (LLVM's C++ library) instead of libstdc++
    export CXXFLAGS="${CXXFLAGS:-} -stdlib=libc++"
    build_cmake "$src_dir/c" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBLAKE3_USE_TBB=OFF
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_libblake3
