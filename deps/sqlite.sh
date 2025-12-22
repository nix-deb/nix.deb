#!/usr/bin/env bash
# Build SQLite (Tier 2)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="sqlite"
VERSION="3.48.0"
# SQLite uses a weird versioning in the URL: 3.48.0 -> 3480000
VERSION_NUM="3480000"
URL="https://www.sqlite.org/2025/sqlite-autoconf-${VERSION_NUM}.tar.gz"

build_sqlite() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL" "sqlite-autoconf-${VERSION_NUM}.tar.gz")

    # Rename directory to standard format
    if [[ -d "$BUILD_DIR/sqlite-autoconf-${VERSION_NUM}" ]]; then
        mv "$BUILD_DIR/sqlite-autoconf-${VERSION_NUM}" "$BUILD_DIR/$NAME-$VERSION"
        src_dir="$BUILD_DIR/$NAME-$VERSION"
    fi

    # Enable recommended compile-time options
    export CFLAGS="$CFLAGS \
        -DSQLITE_ENABLE_FTS5 \
        -DSQLITE_ENABLE_RTREE \
        -DSQLITE_ENABLE_JSON1 \
        -DSQLITE_ENABLE_COLUMN_METADATA \
        -DSQLITE_SECURE_DELETE \
        -DSQLITE_ENABLE_UNLOCK_NOTIFY \
        -DSQLITE_ENABLE_DBSTAT_VTAB \
        -DSQLITE_ENABLE_STMTVTAB"

    build_autoconf "$src_dir" \
        --disable-tcl \
        --disable-readline \
        --disable-dynamic-extensions
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_sqlite
