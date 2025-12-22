#!/usr/bin/env bash
# Build cURL (Tier 5 - many dependencies)
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

NAME="curl"
VERSION="8.12.1"
URL="https://curl.se/download/curl-${VERSION}.tar.xz"

build_curl() {
    local src_dir
    src_dir=$(fetch_source "$NAME" "$VERSION" "$URL" "curl-${VERSION}.tar.xz")

    # cURL has many optional features. We enable what we need and disable
    # things that would add unwanted dependencies (like Kerberos).

    build_autoconf "$src_dir" \
        --with-openssl="$PREFIX" \
        --with-zlib="$PREFIX" \
        --with-brotli="$PREFIX" \
        --with-zstd="$PREFIX" \
        --with-nghttp2="$PREFIX" \
        --with-libssh2="$PREFIX" \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
        --without-gssapi \
        --without-libpsl \
        --without-libidn2 \
        --disable-ldap \
        --disable-ldaps \
        --disable-rtsp \
        --disable-dict \
        --disable-telnet \
        --disable-tftp \
        --disable-pop3 \
        --disable-imap \
        --disable-smb \
        --disable-smtp \
        --disable-gopher \
        --disable-mqtt \
        --disable-manual \
        --enable-threaded-resolver
}

setup_paths
setup_clang
build_if_needed "$NAME" "$VERSION" build_curl
