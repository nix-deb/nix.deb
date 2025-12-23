#!/usr/bin/env bash
# Build libseccomp (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# libseccomp provides syscall filtering for sandboxing.
# Critical for Nix's sandbox functionality. Version >= 2.5.5 required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="libseccomp"
VERSION="2.5.5"
URL="https://github.com/seccomp/libseccomp/releases/download/v${VERSION}/libseccomp-${VERSION}.tar.gz"

build_libseccomp() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_autoconf "$src_dir" \
        --disable-dependency-tracking
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_libseccomp
