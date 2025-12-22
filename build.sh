#!/usr/bin/env bash
# Main build orchestration for nix.deb
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/deps/common.sh"

# Default values
TARGET_DISTRO=""
TARGET_ARCH="x86_64"
PACKAGE="nix"
BUILD_DEPS_ONLY=false
SKIP_DEPS=false
CLEAN=false

# Supported distributions
DEBIAN_DISTROS=(stretch buster bullseye bookworm trixie)
UBUNTU_DISTROS=(xenial bionic focal jammy noble)

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build Nix or Lix for Debian/Ubuntu distributions.

Options:
    --distro DISTRO     Target distribution (e.g., debian:bookworm, ubuntu:noble)
    --arch ARCH         Target architecture (default: x86_64)
    --package PKG       Package to build: nix or lix (default: nix)
    --deps-only         Only build dependencies, not the final package
    --skip-deps         Skip dependency building (use pre-built deps)
    --clean             Clean build directory before building
    --all               Build for all supported distributions
    -h, --help          Show this help message

Supported distributions:
    Debian: ${DEBIAN_DISTROS[*]}
    Ubuntu: ${UBUNTU_DISTROS[*]}

Examples:
    $0 --distro debian:bookworm --package nix
    $0 --distro ubuntu:noble --package lix
    $0 --all --package nix
EOF
}

parse_distro() {
    local distro="$1"

    case "$distro" in
        debian:*)
            TARGET_DISTRO="debian-${distro#debian:}"
            ;;
        ubuntu:*)
            TARGET_DISTRO="ubuntu-${distro#ubuntu:}"
            ;;
        *)
            die "Invalid distro format: $distro (expected debian:NAME or ubuntu:NAME)"
            ;;
    esac
}

validate_distro() {
    local distro="$1"
    local codename="${distro#*-}"
    local family="${distro%-*}"

    case "$family" in
        debian)
            for d in "${DEBIAN_DISTROS[@]}"; do
                [[ "$d" == "$codename" ]] && return 0
            done
            ;;
        ubuntu)
            for d in "${UBUNTU_DISTROS[@]}"; do
                [[ "$d" == "$codename" ]] && return 0
            done
            ;;
    esac

    die "Unknown distribution: $distro"
}

# Build all dependencies in order
build_dependencies() {
    log_info "Building dependencies for $TARGET_DISTRO..."

    # Tier 0: No dependencies
    local tier0_deps=(zlib bzip2 xz zstd brotli libcpuid libseccomp attr libunistring)

    # Add Nix-specific tier 0
    if [[ "$PACKAGE" == "nix" ]]; then
        tier0_deps+=(libsodium libblake3)
    fi

    for dep in "${tier0_deps[@]}"; do
        "$SCRIPT_DIR/deps/$dep.sh"
    done

    # Tier 1
    local tier1_deps=(acl openssl boehm-gc c-ares llhttp)
    if [[ "$PACKAGE" == "nix" ]]; then
        tier1_deps+=(pcre2)
    fi
    if [[ "$PACKAGE" == "lix" ]]; then
        tier1_deps+=(ncurses)
    fi

    for dep in "${tier1_deps[@]}"; do
        "$SCRIPT_DIR/deps/$dep.sh"
    done

    # Tier 2
    local tier2_deps=(libidn2 libxml2 editline nghttp2 sqlite)

    for dep in "${tier2_deps[@]}"; do
        "$SCRIPT_DIR/deps/$dep.sh"
    done

    # Tier 3
    local tier3_deps=(libssh2 ngtcp2 nghttp3 libpsl lowdown)
    if [[ "$PACKAGE" == "nix" ]]; then
        tier3_deps+=(icu onetbb)
    fi
    if [[ "$PACKAGE" == "lix" ]]; then
        tier3_deps+=(capnproto)
    fi

    for dep in "${tier3_deps[@]}"; do
        "$SCRIPT_DIR/deps/$dep.sh"
    done

    # Tier 4
    local tier4_deps=(libarchive boost)
    if [[ "$PACKAGE" == "nix" ]]; then
        tier4_deps+=(libgit2)
    fi

    for dep in "${tier4_deps[@]}"; do
        "$SCRIPT_DIR/deps/$dep.sh"
    done

    # Tier 5
    "$SCRIPT_DIR/deps/curl.sh"

    # Tier 6 (optional AWS)
    # TODO: Add AWS SDK build if needed

    log_success "All dependencies built for $TARGET_DISTRO"
}

# Build the final package
build_package() {
    log_info "Building $PACKAGE for $TARGET_DISTRO..."

    "$SCRIPT_DIR/packages/$PACKAGE/build.sh"

    log_success "Built $PACKAGE for $TARGET_DISTRO"
}

# Create .deb package
create_deb() {
    log_info "Creating .deb package for $PACKAGE on $TARGET_DISTRO..."

    # TODO: Implement deb packaging

    log_success "Created .deb package"
}

# Build for a single distribution
build_single() {
    validate_distro "$TARGET_DISTRO"
    export TARGET_DISTRO TARGET_ARCH PACKAGE

    setup_paths
    setup_clang

    # Ensure sysroot is set up
    if [[ ! -d "$SYSROOT" ]]; then
        log_info "Setting up sysroot for $TARGET_DISTRO..."
        "$SCRIPT_DIR/sysroots/setup.sh" "$TARGET_DISTRO"
    fi

    if [[ "$CLEAN" == true ]]; then
        log_info "Cleaning build directory..."
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi

    if [[ "$SKIP_DEPS" != true ]]; then
        build_dependencies
    fi

    if [[ "$BUILD_DEPS_ONLY" != true ]]; then
        build_package
        create_deb
    fi
}

# Build for all distributions
build_all() {
    local all_distros=()

    for d in "${DEBIAN_DISTROS[@]}"; do
        all_distros+=("debian-$d")
    done

    for d in "${UBUNTU_DISTROS[@]}"; do
        all_distros+=("ubuntu-$d")
    done

    for distro in "${all_distros[@]}"; do
        log_info "=== Building for $distro ==="
        TARGET_DISTRO="$distro"
        build_single
    done

    log_success "All distributions built!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)
            parse_distro "$2"
            shift 2
            ;;
        --arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        --package)
            PACKAGE="$2"
            if [[ "$PACKAGE" != "nix" && "$PACKAGE" != "lix" ]]; then
                die "Invalid package: $PACKAGE (must be 'nix' or 'lix')"
            fi
            shift 2
            ;;
        --deps-only)
            BUILD_DEPS_ONLY=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --all)
            build_all
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

if [[ -z "$TARGET_DISTRO" ]]; then
    usage
    die "No distribution specified. Use --distro or --all."
fi

build_single
