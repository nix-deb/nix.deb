# Dependency Analysis

This document analyzes the dependencies of Nix and Lix, categorizes them, and plans the build order for static linking.

## Build Order

Dependencies must be built in topological order. Libraries with no dependencies are built first, then libraries that depend only on those, and so on.

### Tier 0: No Dependencies (leaf libraries)
These libraries have no dependencies beyond glibc and can be built first.

| Library | Version | Notes |
|---------|---------|-------|
| zlib | 1.3.1 | Compression, widely used |
| bzip2 | 1.0.8 | Compression |
| xz (liblzma) | 5.8.1 | Compression |
| zstd | 1.5.7 | Compression |
| brotli | 1.1.0 | Compression |
| libsodium | 1.0.20 | Cryptography (Nix only) |
| libblake3 | 1.8.2 | BLAKE3 hashing (Nix only) |
| libcpuid | 0.8.1 | CPU feature detection |
| libseccomp | 2.6.0 | Sandboxing |
| attr | 2.5.2 | Extended attributes |
| libunistring | 1.4.1 | Unicode string handling |

### Tier 1: Depends on Tier 0
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| acl | 2.3.2 | attr | Access control lists |
| OpenSSL | 3.6.0 | zlib | TLS/crypto - **critical** |
| ncurses | 6.5 | (none) | Terminal handling (Lix) |
| Boehm GC | 8.2.8 | (none) | Garbage collector |
| PCRE2 | 10.46 | (none) | Regular expressions (Nix) |
| c-ares | 1.34.5 | (none) | Async DNS |
| llhttp | 9.3.0 | (none) | HTTP parser |

### Tier 2: Depends on Tier 1
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| libidn2 | 2.3.8 | libunistring | Internationalized domain names |
| libxml2 | 2.15.1 | zlib, xz | XML parsing |
| editline | 1.17.1 | ncurses | Command line editing |
| nghttp2 | 1.67.1 | zlib | HTTP/2 |
| SQLite | 3.50.4 | zlib (optional) | Database |

### Tier 3: Depends on Tier 2
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| libssh2 | 1.11.1 | OpenSSL, zlib | SSH protocol |
| ngtcp2 | 1.17.0 | OpenSSL, nghttp2 | QUIC |
| nghttp3 | 1.12.0 | (none) | HTTP/3 |
| libpsl | 0.21.5 | libidn2, libunistring | Public suffix list |
| lowdown | 2.0.4 | (none) | Markdown |
| ICU | 76.1 | (none) | Unicode (Nix only) |
| oneTBB | 2022.3.0 | (none) | Threading (Nix only) |
| Cap'n Proto | 1.2.0 | (none) | Serialization (Lix only) |

### Tier 4: Depends on Tier 3
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| libarchive | 3.8.2 | zlib, bzip2, xz, zstd, OpenSSL, acl, attr, libxml2 | Archive handling |
| libgit2 | 1.9.2 | OpenSSL, zlib, libssh2, PCRE2 | Git operations (Nix only) |
| Boost | 1.87.0 | zlib, bzip2, xz, zstd, ICU (optional) | C++ libraries |

### Tier 5: Depends on Tier 4
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| cURL | 8.17.0 | OpenSSL, zlib, brotli, zstd, c-ares, nghttp2, ngtcp2, nghttp3, libidn2, libpsl, libssh2 | HTTP client |

### Tier 6: AWS SDK (optional, for S3 support)
| Library | Version | Dependencies | Notes |
|---------|---------|--------------|-------|
| aws-c-common | - | (none) | AWS base |
| s2n-tls | 1.5.27 | OpenSSL | AWS TLS |
| aws-c-io | - | aws-c-common, s2n-tls | AWS I/O |
| aws-crt-cpp | 0.34.3 | aws-c-* libraries | AWS C++ runtime |
| aws-sdk-cpp | 1.11.647 | aws-crt-cpp, OpenSSL, zlib, curl | AWS SDK |

### Tier 7: Final Targets
| Package | Dependencies |
|---------|--------------|
| **Nix** | All of the above except Cap'n Proto, ncurses |
| **Lix** | All of the above except libgit2, libblake3, oneTBB, ICU, PCRE2, libsodium |

## Dependency Categories

### Must Build Statically
These are required and must be statically linked:

- **Compression**: zlib, bzip2, xz, zstd, brotli
- **Crypto/TLS**: OpenSSL, libsodium (Nix)
- **Database**: SQLite
- **Archive**: libarchive
- **Network**: cURL, nghttp2, c-ares, libssh2
- **Core**: Boost, Boehm GC

### Can Potentially Skip/Disable

Some dependencies may be optional or can be avoided by configuring Nix/Lix appropriately:

| Dependency | Why It Exists | Can Disable? |
|------------|---------------|--------------|
| Kerberos (krb5) | cURL/libssh2 auth | Yes - configure cURL without GSSAPI |
| keyutils | Kerberos dependency | Yes - if we skip Kerberos |
| libpsl | cURL cookie handling | Maybe - configure cURL without PSL |
| libidn2 | Internationalized URLs | Maybe - configure cURL without IDN |
| AWS SDK | S3 binary cache support | Maybe - build without S3 support |
| libgit2 | Git fetcher in Nix | Probably required for flakes |
| ICU | Unicode in Nix language | May be required |
| oneTBB | Parallel evaluation | May be required for performance |

### Problematic Dependencies (dlopen concerns)

Some libraries use `dlopen` at runtime which breaks our static linking goal:

| Library | dlopen Usage | Mitigation |
|---------|--------------|------------|
| OpenSSL | Engine loading | Disable engine support (`no-engine`) |
| OpenSSL | Legacy providers | Build with `no-legacy` if not needed |
| NSS | Module loading | Don't use NSS, use OpenSSL |
| Kerberos | Plugin loading | Avoid Kerberos entirely |
| ICU | Data loading | Build with static data |

## Static Linking Configuration

### OpenSSL
```bash
./Configure linux-x86_64 \
    no-shared \
    no-engine \
    no-dso \
    no-legacy \
    --prefix=$PREFIX \
    --openssldir=$PREFIX/ssl
```

### cURL
```bash
./configure \
    --disable-shared \
    --enable-static \
    --with-openssl \
    --without-gssapi \
    --without-libpsl \
    --with-nghttp2 \
    --with-zstd \
    --with-brotli
```

### Boost
```bash
./b2 \
    link=static \
    runtime-link=static \
    threading=multi \
    --without-python
```

### libarchive
```bash
./configure \
    --disable-shared \
    --enable-static \
    --without-nettle \
    --with-openssl \
    --with-zlib \
    --with-bz2lib \
    --with-liblzma \
    --with-zstd
```

## glibc Compatibility

The oldest glibc we target is 2.23 (Ubuntu 16.04 Xenial). We must ensure:

1. No use of glibc symbols newer than 2.23
2. Build with appropriate `-D_GNU_SOURCE` and feature test macros
3. Test binaries on actual target systems or with symbol version checking

### Symbol Version Checking
```bash
# Check for glibc version requirements
objdump -T binary | grep GLIBC_ | sed 's/.*GLIBC_//' | sort -V | tail -1
```

## Build Matrix

| Dependency | Nix | Lix | Static | Notes |
|------------|-----|-----|--------|-------|
| zlib | x | x | x | |
| bzip2 | x | x | x | |
| xz | x | x | x | |
| zstd | x | x | x | |
| brotli | x | x | x | |
| OpenSSL | x | x | x | no-engine, no-dso |
| Boost | x | | x | |
| cURL | x | x | x | minimal features |
| SQLite | x | x | x | |
| libarchive | x | x | x | |
| Boehm GC | x | x | x | |
| libseccomp | x | x | x | |
| libcpuid | x | x | x | |
| editline | x | x | x | |
| lowdown | x | x | x | |
| acl | x | x | x | |
| attr | x | x | x | |
| nghttp2 | x | x | x | |
| c-ares | x | x | x | |
| libgit2 | x | | x | Nix only |
| libblake3 | x | | x | Nix only |
| libsodium | x | | x | Nix only |
| oneTBB | x | | x | Nix only |
| ICU | x | | x | Nix only |
| PCRE2 | x | | x | Nix only |
| Cap'n Proto | | x | x | Lix only |
| ncurses | | x | x | Lix only |
| AWS SDK | ? | ? | x | Optional |
