#!/usr/bin/env bash
# Build attr (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# attr provides extended attribute support.
# Required by acl and libarchive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="attr"
VERSION="2.5.2"
URL="https://download.savannah.nongnu.org/releases/attr/attr-${VERSION}.tar.gz"

build_attr() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    build_autoconf "$src_dir" \
        --disable-dependency-tracking
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_attr
