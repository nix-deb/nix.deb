#!/usr/bin/env bash
# Build libsodium (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# libsodium is a cryptography library used by Nix's libutil.
# We build the full library (not --enable-minimal) to ensure all
# features Nix needs are available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="libsodium"
VERSION="1.0.20"
URL="https://github.com/jedisct1/libsodium/releases/download/${VERSION}-RELEASE/libsodium-${VERSION}.tar.gz"

build_libsodium() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_autoconf "$src_dir" \
        --disable-dependency-tracking \
        --disable-debug
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_libsodium
