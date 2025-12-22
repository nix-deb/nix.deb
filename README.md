# nix.deb

Build Nix and Lix package managers from source for Debian and Ubuntu, with minimal runtime dependencies.

## Goals

- Build [Nix](https://github.com/NixOS/nix) and [Lix](https://git.lix.systems/lix-project/lix) from source
- Produce `.deb` packages served via an apt repository on GitHub Pages
- **Minimal runtime dependencies**: only glibc (version-appropriate for each target distro)
- All other dependencies statically linked into the binaries
- No Nix required to build Nix

## Supported Distributions

### Debian
| Release | Codename | glibc Version | Support Status |
|---------|----------|---------------|----------------|
| 9 | Stretch | 2.24 | oldoldstable |
| 10 | Buster | 2.28 | oldstable |
| 11 | Bullseye | 2.31 | stable |
| 12 | Bookworm | 2.36 | stable |
| 13 | Trixie | 2.40 | testing |

### Ubuntu
| Release | Codename | glibc Version | Support Status |
|---------|----------|---------------|----------------|
| 16.04 | Xenial | 2.23 | ESM |
| 18.04 | Bionic | 2.27 | ESM |
| 20.04 | Focal | 2.31 | LTS |
| 22.04 | Jammy | 2.35 | LTS |
| 24.04 | Noble | 2.39 | LTS |

## Architecture

### Build Strategy

We use Clang's cross-compilation capabilities to target different glibc versions without Docker containers. By configuring Clang with the appropriate sysroot and target triple, we can build on a modern GitHub Actions runner while producing binaries compatible with older distributions.

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Runner                     │
│                   (Ubuntu latest + Clang)                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Sysroot Downloads                      │ │
│  │  (glibc headers + essential libs for each target)      │ │
│  └────────────────────────────────────────────────────────┘ │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Clang Cross-Compilation                    │ │
│  │  --target=x86_64-linux-gnu --sysroot=/path/to/sysroot  │ │
│  └────────────────────────────────────────────────────────┘ │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Static Dependencies Build (per target)          │ │
│  │  (OpenSSL, Boost, curl, SQLite, libarchive, ...)       │ │
│  └────────────────────────────────────────────────────────┘ │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Nix / Lix Build                        │ │
│  └────────────────────────────────────────────────────────┘ │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   .deb Packaging                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐    ┌─────────────────────────────────┐
│   GitHub Releases   │    │        GitHub Pages apt         │
│   (.deb files)      │◄───│  (Packages, Release, InRelease) │
└─────────────────────┘    └─────────────────────────────────┘
```

### Compiler

We use Clang (latest available on GitHub Actions runners) for all builds:
- Cross-compilation via `--target` and `--sysroot` flags
- Consistent toolchain across all target distributions
- Better static analysis and diagnostics
- Modern C++ standard support

## Dependencies

See [docs/dependencies.md](docs/dependencies.md) for the full dependency analysis.

### Core Dependencies (both Nix and Lix)
- OpenSSL - TLS/crypto
- Boost - C++ libraries
- cURL - HTTP client
- SQLite - Database
- libarchive - Archive handling
- Brotli, zstd, bzip2, zlib, xz - Compression
- libseccomp - Sandboxing
- Boehm GC - Garbage collection (for Nix language)
- editline - Command line editing
- lowdown - Markdown processing

### Nix-specific
- libgit2 - Git operations
- libblake3 - BLAKE3 hashing
- oneTBB - Threading
- ICU - Unicode support
- PCRE2 - Regular expressions

### Lix-specific
- Cap'n Proto / KJ - Serialization and async I/O
- ncurses - Terminal handling

### Transitive Dependencies
Many libraries pull in additional dependencies (nghttp2, c-ares, libidn2, etc.) which we'll also build statically.

## Installation

```bash
# Add the repository
curl -fsSL https://nix-deb.github.io/nix.deb/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/nix-deb.gpg
echo "deb [signed-by=/usr/share/keyrings/nix-deb.gpg] https://nix-deb.github.io/nix.deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nix-deb.list

# Install Nix or Lix
sudo apt update
sudo apt install nix    # or: sudo apt install lix
```

## Building Locally

```bash
# Build for a specific distribution
./build.sh --distro debian:bookworm --package nix

# Build all distributions
./build.sh --all
```

## Project Structure

```
.
├── README.md
├── build.sh                    # Main build orchestration
├── docs/
│   ├── dependencies.md         # Dependency analysis
│   └── build-notes.md          # Build configuration notes
├── sysroots/                   # Sysroot setup scripts
│   └── setup.sh                # Download/configure sysroots
├── deps/                       # Dependency build scripts
│   ├── common.sh               # Shared build functions
│   ├── openssl.sh
│   ├── boost.sh
│   ├── curl.sh
│   └── ...
├── packages/
│   ├── nix/                    # Nix build configuration
│   │   ├── build.sh
│   │   └── debian/             # Debian packaging files
│   └── lix/                    # Lix build configuration
│       ├── build.sh
│       └── debian/
├── apt/                        # apt repository generation
│   └── generate.sh             # Generate Packages/Release/InRelease
└── .github/
    └── workflows/
        ├── build.yml           # Main CI/CD workflow
        └── publish.yml         # apt repository publishing
```

## License

This project is licensed under the [LGPL-2.1](LICENSE), aligning with Nix and Lix licensing.

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
