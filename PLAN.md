# nix.deb Development Plan

## Overview

Build Nix and Lix from source for Debian/Ubuntu with only glibc as a runtime dependency.

## Completed

- [x] Project scaffolding (README, LICENSE, directory structure)
- [x] Dependency analysis and build order documentation
- [x] Common build functions (`deps/common.sh`)
- [x] Sysroot setup script for cross-compilation
- [x] GitHub Actions workflow structure
- [x] apt repository generation script
- [x] Example dependency build scripts (zlib, bzip2, xz, zstd, openssl, sqlite, curl)

## Remaining Work

### Phase 1: Dependency Build Scripts

Create build scripts for all remaining dependencies. Each script follows the pattern in `deps/common.sh`.

#### Tier 0 (no dependencies)
- [x] `deps/libcxx.sh` - LLVM C++ runtime (libunwind, libc++abi, libc++) - **must build first**
- [x] `deps/brotli.sh` - Brotli compression
- [x] `deps/libsodium.sh` - Cryptography (Nix only)
- [x] `deps/libblake3.sh` - BLAKE3 hashing (Nix only)
- [x] `deps/libcpuid.sh` - CPU feature detection
- [x] `deps/libseccomp.sh` - Sandboxing
- [x] `deps/attr.sh` - Extended attributes
- [x] `deps/libunistring.sh` - Unicode strings

#### Tier 1 (depends on Tier 0)
- [ ] `deps/acl.sh` - Access control lists (depends on attr)
- [ ] `deps/boehm-gc.sh` - Garbage collector
- [ ] `deps/c-ares.sh` - Async DNS resolver
- [ ] `deps/llhttp.sh` - HTTP parser
- [ ] `deps/pcre2.sh` - Regular expressions (Nix only)
- [ ] `deps/ncurses.sh` - Terminal handling (Lix only)

#### Tier 2 (depends on Tier 1)
- [ ] `deps/libidn2.sh` - Internationalized domain names
- [ ] `deps/libxml2.sh` - XML parsing
- [ ] `deps/editline.sh` - Command line editing
- [ ] `deps/nghttp2.sh` - HTTP/2

#### Tier 3 (depends on Tier 2)
- [ ] `deps/libssh2.sh` - SSH protocol
- [ ] `deps/ngtcp2.sh` - QUIC
- [ ] `deps/nghttp3.sh` - HTTP/3
- [ ] `deps/libpsl.sh` - Public suffix list
- [ ] `deps/lowdown.sh` - Markdown processor
- [ ] `deps/icu.sh` - Unicode (Nix only)
- [ ] `deps/onetbb.sh` - Threading (Nix only)
- [ ] `deps/capnproto.sh` - Serialization (Lix only)

#### Tier 4 (depends on Tier 3)
- [ ] `deps/libarchive.sh` - Archive handling
- [ ] `deps/boost.sh` - C++ libraries
- [ ] `deps/libgit2.sh` - Git operations (Nix only)

#### Tier 5 (curl - already done)
- [x] `deps/curl.sh` - HTTP client

#### Tier 6 (AWS SDK - optional)
- [ ] `deps/aws-c-common.sh`
- [ ] `deps/s2n-tls.sh`
- [ ] `deps/aws-c-io.sh`
- [ ] `deps/aws-crt-cpp.sh`
- [ ] `deps/aws-sdk-cpp.sh`

### Phase 2: Package Build Scripts

- [ ] `packages/nix/build.sh` - Build Nix from source
- [ ] `packages/lix/build.sh` - Build Lix from source

Nix uses Meson. Lix also uses Meson. Both will need careful configuration to:
- Find our statically-built dependencies
- Disable optional features that add unwanted dependencies
- Link statically where possible

### Phase 3: Debian Packaging

- [ ] `packages/nix/debian/control` - Package metadata
- [ ] `packages/nix/debian/rules` - Build rules
- [ ] `packages/nix/debian/postinst` - Post-install script (create nix users/groups, /nix directory)
- [ ] `packages/nix/debian/prerm` - Pre-remove script
- [ ] `packages/lix/debian/*` - Same for Lix

### Phase 4: Testing

- [ ] Test sysroot setup for each target distribution
- [ ] Verify glibc symbol versions in built binaries
- [ ] Test installation on actual Debian/Ubuntu systems
- [ ] Test basic Nix/Lix operations (nix-build, nix-shell, flakes)

### Phase 5: CI/CD Finalization

- [ ] Set up GPG key for apt signing (repository secret)
- [ ] Test full GitHub Actions pipeline
- [ ] Configure GitHub Pages deployment
- [ ] Create initial release

## Technical Notes

### glibc Compatibility

Each distribution gets its own complete build targeting its native glibc version:

| Distribution | glibc | Notes |
|--------------|-------|-------|
| Debian 9 (Stretch) | 2.24 | oldoldstable |
| Ubuntu 16.04 (Xenial) | 2.23 | ESM |
| Ubuntu 18.04 (Bionic) | 2.27 | ESM |
| Debian 10 (Buster) | 2.28 | oldstable |
| Ubuntu 20.04 (Focal) | 2.31 | LTS |
| Debian 11 (Bullseye) | 2.31 | oldstable |
| Ubuntu 22.04 (Jammy) | 2.35 | LTS |
| Debian 12 (Bookworm) | 2.36 | stable |
| Ubuntu 24.04 (Noble) | 2.39 | LTS |
| Debian 13 (Trixie) | 2.40 | testing |

This means 10 complete builds (all dependencies + Nix/Lix) for each release. The apt
repository structure naturally scopes packages by codename, so users get binaries
optimized for their specific distribution rather than a lowest-common-denominator build.

Benefits:
- Newer distros can use newer glibc features
- No artificial constraints from oldest target
- Packages are truly native to each distribution

### Static Linking Concerns

Libraries that use dlopen and need special handling:
- **OpenSSL**: Build with `no-engine no-dso`
- **ICU**: Build with static data files
- **Kerberos**: Avoid entirely (configure curl without GSSAPI)

### Nix Build System

Nix uses Meson. Key configure options to investigate:
- How to point at our custom-built dependencies
- How to disable AWS S3 support if we skip the AWS SDK
- How to ensure static linking

### Lix Build System

Lix also uses Meson. Similar investigation needed:
- Cap'n Proto integration
- Custom dependency paths
- Static linking configuration

### Nix Dependency Requirements (from meson.build analysis)

**libutil** (core utility library) requires:
- **libblake3** >= 1.8.2 (pkg-config)
- **boost** >= 1.87.0 (modules: context, coroutine, iostreams, url)
- **openssl/libcrypto** >= 1.1.1
- **libarchive** >= 3.1.2
- **libsodium**
- **brotli** (libbrotlicommon, libbrotlidec, libbrotlienc)
- **libcpuid** >= 0.7.0 (optional)
- **nlohmann_json** >= 3.9

**libstore** (store operations) requires:
- **libseccomp** >= 2.5.5 (Linux only, critical for sandboxing)
- **sqlite3** >= 3.6.19
- **libcurl** >= 7.75.0
- **boost** (modules: container, url)
- **nlohmann_json** >= 3.9
- AWS CRT libraries (optional, for S3 support)

### Tier 0 Dependency Configure Options

| Dependency | Build System | Configure Options | Notes |
|------------|-------------|-------------------|-------|
| **brotli** | CMake | `-DBUILD_SHARED_LIBS=OFF` | Produces 3 libs: brotlicommon, brotlidec, brotlienc |
| **libsodium** | autoconf | `--disable-shared --enable-static` | Keep full API (avoid `--enable-minimal`), keep ASM |
| **libblake3** | CMake | `-DBUILD_SHARED_LIBS=OFF -DBLAKE3_USE_TBB=OFF` | Auto-detects amd64-asm for x86_64 |
| **libcpuid** | CMake | `-DBUILD_SHARED_LIBS=OFF` | Optional, CPU feature detection |
| **libseccomp** | autoconf | `--disable-shared --enable-static` | Skip `--enable-python`, version >= 2.5.5 |
| **attr** | autoconf | `--disable-shared --enable-static` | Required by acl and libarchive |
| **libunistring** | autoconf | `--disable-shared --enable-static` | Keep namespacing (default), needed by libidn2 |

### Optimization Levels

All dependencies are built with `-O2` optimization (CMake Release mode default) which provides
a good balance of performance and compile time. We explicitly avoid `-O3` to reduce binary
size and potential for optimization-related bugs. The `-fPIC` flag is always enabled for
position-independent code.

## Development Workflow

### The Problem

Development machines (NixOS, macOS) don't match the target environment (Debian/Ubuntu).
We need to:
- Iterate quickly on build scripts
- Avoid path dependence (something "works" only because of prior experimentation steps)
- Have high fidelity to the actual target environment

### The Solution: Nix-built QEMU VMs with QEMU snapshots

We use Nix to build minimal QEMU VM images for each target distribution. This gives us:

1. **Reproducible VM images** - Version controlled, rebuildable from scratch
2. **Fast iteration via QEMU snapshots** - Instant rollback to clean state
3. **High fidelity** - Real Debian/Ubuntu, not containers
4. **No networking required** - 9P filesystem shares data between host and guest
5. **Works everywhere** - NixOS, macOS (via lima or native QEMU)

```
┌─────────────────────────────────────────────────────────────────┐
│                         Host (NixOS/macOS)                       │
│                                                                  │
│  ┌──────────────────┐    ┌─────────────────────────────────┐    │
│  │   Nix builds:    │    │         QEMU VM (Debian)        │    │
│  │  - VM image      │    │  ┌─────────────────────────┐    │    │
│  │  - Source tars   │───▶│  │  /mnt/host (9P mount)   │    │    │
│  │  - Build scripts │    │  │  - sources/             │    │    │
│  │  - LLVM tarball  │    │  │  - scripts/             │    │    │
│  └──────────────────┘    │  │  - output/              │    │    │
│                          │  └─────────────────────────┘    │    │
│                          │                                  │    │
│  ┌──────────────────┐    │  QEMU qcow2 snapshots:          │    │
│  │ Snapshot manager │───▶│  - instant rollback             │    │
│  │  vm snapshot     │    │  - verify from clean state      │    │
│  │  vm restore      │    │                                  │    │
│  │  vm run          │    └─────────────────────────────────┘    │
│  └──────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow

```bash
# 1. Build the VM image for a target distro
nix build .#vm-debian-bookworm

# 2. Start the VM
./result/bin/vm run

# 3. Inside VM: run build scripts from 9P mount
cd /mnt/host
./deps/zlib.sh

# 4. Iterate, experiment, debug...

# 5. Think you have it working? Restore and verify:
./result/bin/vm restore    # instant rollback to clean state
./result/bin/vm run
# Run the "final" command only - if it works from clean, it's real

# 6. Once verified, commit the build script
```

### Implementation Plan

#### Phase 0: VM Infrastructure (before Phase 1)

- [ ] `nix/vm/base.nix` - Common VM configuration (QEMU, btrfs, 9P)
- [ ] `nix/vm/debian.nix` - Debian-specific image builder
- [ ] `nix/vm/ubuntu.nix` - Ubuntu-specific image builder
- [ ] `nix/vm/snapshot.sh` - Snapshot management wrapper
- [ ] `nix/sources.nix` - Fetch all dependency source tarballs
- [ ] `flake.nix` - Expose VM images as flake outputs

Each VM image includes:
- Minimal base system (official cloud images)
- Build tools: cmake, meson, ninja, autoconf, automake, libtool, pkg-config
- LLVM/Clang 21.1.8 (fetched by Nix, consistent across all distros)
- SSH server with key auth (for non-interactive command execution)
- No internet access (isolated), but localhost SSH for control

**Compiler standardization**: We use a single version of LLVM/Clang (21.1.8) across
all target distributions, fetched from GitHub releases and installed via cloud-init.
This ensures consistent compiler behavior regardless of target distro. We do NOT use
gcc/g++ - clang only.

QEMU configuration:
- `-nic user,hostfwd=tcp:127.0.0.1:2222-:22` for SSH access
- 9P virtio for filesystem sharing
- qcow2 disk with QEMU internal snapshots for rollback

The 9P share (`/mnt/host` in guest) provides:
- Source tarballs (fetched by Nix, content-addressed)
- Build scripts (this repository)
- LLVM tarball (fetched by Nix)
- Output directory (for built artifacts)

VM control wrapper commands:
```bash
vm run              # Start the VM (backgrounds, waits for SSH ready)
vm exec "command"   # Run command in VM via SSH, return output
vm snapshot         # Take a named snapshot of current state
vm restore          # Restore to last snapshot
vm stop             # Shutdown the VM
```

#### Verification Gate

Before marking any build script as complete:
1. `vm restore` to clean state
2. Run the build script
3. If it succeeds from clean, it's verified
4. Push to GitHub and confirm CI passes (non-interactive GitHub Actions)

This two-stage verification catches:
- Path dependence from local experimentation
- Any remaining differences between VM and GitHub Actions environment

## Open Questions

1. **AWS SDK**: Is S3 binary cache support required? The AWS SDK is large and has many sub-dependencies. We could make this optional.

2. **libgit2**: Is this required for flakes support in Nix? If so, it's mandatory.

3. **ICU**: Can Nix function without full ICU support, or is there a minimal subset we can use?

4. **Boost subset**: Which Boost libraries does Nix actually use? We should only build those.
