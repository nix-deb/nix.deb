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
- [ ] `deps/brotli.sh` - Brotli compression
- [ ] `deps/libsodium.sh` - Cryptography (Nix only)
- [ ] `deps/libblake3.sh` - BLAKE3 hashing (Nix only)
- [ ] `deps/libcpuid.sh` - CPU feature detection
- [ ] `deps/libseccomp.sh` - Sandboxing
- [ ] `deps/attr.sh` - Extended attributes
- [ ] `deps/libunistring.sh` - Unicode strings

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

Target glibc versions by distribution:
- Ubuntu 16.04 (Xenial): glibc 2.23
- Ubuntu 18.04 (Bionic): glibc 2.27
- Debian 9 (Stretch): glibc 2.24
- Debian 10 (Buster): glibc 2.28
- Ubuntu 20.04 (Focal): glibc 2.31
- Debian 11 (Bullseye): glibc 2.31
- Ubuntu 22.04 (Jammy): glibc 2.35
- Debian 12 (Bookworm): glibc 2.36
- Ubuntu 24.04 (Noble): glibc 2.39
- Debian 13 (Trixie): glibc 2.40

The oldest target is glibc 2.23. All binaries must avoid symbols newer than this.

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

## Open Questions

1. **AWS SDK**: Is S3 binary cache support required? The AWS SDK is large and has many sub-dependencies. We could make this optional.

2. **libgit2**: Is this required for flakes support in Nix? If so, it's mandatory.

3. **ICU**: Can Nix function without full ICU support, or is there a minimal subset we can use?

4. **Boost subset**: Which Boost libraries does Nix actually use? We should only build those.

5. **Test strategy**: How do we verify the built packages work correctly on target distributions without spinning up VMs for each?
