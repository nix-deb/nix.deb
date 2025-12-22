{ pkgs, perSystem, name, family, codename }:
let
  sshKeyPair = perSystem.self.vm-ssh-key;
  tools = perSystem.self.tools-json;
  llvmSrc = perSystem.self.llvm;
  ninjaDir = perSystem.self.ninja;
  cmakeDir = perSystem.self.cmake;
  mesonSrc = perSystem.self.meson;

  userData = pkgs.writeText "user-data" ''
#cloud-config
hostname: ${name}
users:
  - name: root
    ssh_authorized_keys:
      - ${builtins.readFile "${sshKeyPair}/id_ed25519.pub"}

package_update: true
packages:
  # Build tools (compilers, ninja, cmake, meson from Nix store via virtiofs)
  - python3
  - pkg-config
  - autoconf
  - automake
  - libtool
  - make
  - bison
  - flex
  - gettext
  - git
  - curl
  - wget
  - ca-certificates
  - xz-utils

mounts:
  - [ host_share, /mnt/host, 9p, "trans=virtio,version=9p2000.L,msize=104857600", "0", "0" ]
  - [ nix_store, /nix/store, virtiofs, "ro", "0", "0" ]

runcmd:
  - mkdir -p /mnt/host /nix/store
  - mount -a
  # Set up symlinks to LLVM tools (shared via virtiofs at /nix/store)
  - ln -sf ${llvmSrc}/bin/clang /usr/local/bin/clang
  - ln -sf ${llvmSrc}/bin/clang++ /usr/local/bin/clang++
  - ln -sf ${llvmSrc}/bin/clang-cpp /usr/local/bin/clang-cpp
  - ln -sf ${llvmSrc}/bin/ld.lld /usr/local/bin/ld.lld
  - ln -sf ${llvmSrc}/bin/lld /usr/local/bin/lld
  - ln -sf ${llvmSrc}/bin/llvm-ar /usr/local/bin/llvm-ar
  - ln -sf ${llvmSrc}/bin/llvm-ranlib /usr/local/bin/llvm-ranlib
  - ln -sf ${llvmSrc}/bin/llvm-nm /usr/local/bin/llvm-nm
  - ln -sf ${llvmSrc}/bin/llvm-objcopy /usr/local/bin/llvm-objcopy
  - ln -sf ${llvmSrc}/bin/llvm-objdump /usr/local/bin/llvm-objdump
  - ln -sf ${llvmSrc}/bin/llvm-strip /usr/local/bin/llvm-strip
  # Ninja from Nix store via virtiofs
  - ln -sf ${ninjaDir}/bin/ninja /usr/local/bin/ninja
  # CMake from Nix store via virtiofs
  - ln -sf ${cmakeDir}/bin/cmake /usr/local/bin/cmake
  - ln -sf ${cmakeDir}/bin/ctest /usr/local/bin/ctest
  - ln -sf ${cmakeDir}/bin/cpack /usr/local/bin/cpack
  # Meson wrapper script (calls python3 with meson.py from Nix store)
  - |
    cat > /usr/local/bin/meson << 'MESON_WRAPPER'
    #!/bin/sh
    exec python3 ${mesonSrc}/meson.py "$@"
    MESON_WRAPPER
  - chmod +x /usr/local/bin/meson
  # Make clang the default CC/CXX
  - update-alternatives --install /usr/bin/cc cc /usr/local/bin/clang 100
  - update-alternatives --install /usr/bin/c++ c++ /usr/local/bin/clang++ 100
  - echo "VM ready" > /var/run/vm-ready
  '';

  metaData = pkgs.writeText "meta-data" ''
    instance-id: ${name}
    local-hostname: ${name}
  '';

in pkgs.runCommand "cloud-init-${name}" {
  nativeBuildInputs = [ pkgs.cloud-utils ];
} ''
  mkdir -p $out
  cloud-localds $out/seed.img ${userData} ${metaData}
''
