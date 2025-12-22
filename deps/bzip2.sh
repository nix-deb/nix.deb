#!/usr/bin/env bash
# Build bzip2 (Tier 0 - no dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="bzip2"
VERSION="1.0.8"
URL="https://sourceware.org/pub/bzip2/bzip2-${VERSION}.tar.gz"

build_bzip2() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL")

    cd "$src_dir"

    # bzip2 uses a plain Makefile, need to override CC and flags
    pmake \
        CC="$CC" \
        CFLAGS="$CFLAGS -D_FILE_OFFSET_BITS=64" \
        AR="${TARGET_ARCH}-linux-gnu-ar" \
        RANLIB="${TARGET_ARCH}-linux-gnu-ranlib" \
        libbz2.a

    # Manual installation of static library and headers
    install -Dm644 libbz2.a "$PREFIX/lib/libbz2.a"
    install -Dm644 bzlib.h "$PREFIX/include/bzlib.h"

    # Create pkg-config file
    mkdir -p "$PREFIX/lib/pkgconfig"
    cat > "$PREFIX/lib/pkgconfig/bzip2.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 compression library
Version: $VERSION
Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
EOF
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_bzip2
