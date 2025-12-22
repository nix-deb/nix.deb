{
  description = "Build Nix and Lix for Debian/Ubuntu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import VM infrastructure
        vmLib = import ./nix/vm { inherit pkgs; };

        # Read tool versions from tools.json (single source of truth)
        tools = builtins.fromJSON (builtins.readFile ./tools.json);

        # LLVM/Clang toolchain
        # Pre-extracted in Nix store, shared via 9P to VMs
        llvmVersion = tools.llvm.version;
        llvmSrc = pkgs.fetchzip {
          url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvmVersion}/LLVM-${llvmVersion}-Linux-X64.tar.xz";
          sha256 = tools.llvm.sha256;
        };
        # Dereference symlinks for 9P sharing (9P can't follow symlinks)
        llvmDir = pkgs.runCommand "llvm-dereferenced" {} ''
          cp -rL ${llvmSrc} $out
        '';

        # Ninja build system
        ninjaVersion = tools.ninja.version;
        ninjaSrc = pkgs.fetchzip {
          url = "https://github.com/ninja-build/ninja/releases/download/v${ninjaVersion}/ninja-linux.zip";
          sha256 = tools.ninja.sha256;
          stripRoot = false;
        };
        # Wrap in bin/ directory for consistent structure
        ninjaDir = pkgs.runCommand "ninja-wrapped" {} ''
          mkdir -p $out/bin
          cp ${ninjaSrc}/ninja $out/bin/
          chmod +x $out/bin/ninja
        '';

        # CMake
        cmakeVersion = tools.cmake.version;
        cmakeDir = pkgs.fetchzip {
          url = "https://github.com/Kitware/CMake/releases/download/v${cmakeVersion}/cmake-${cmakeVersion}-linux-x86_64.tar.gz";
          sha256 = tools.cmake.sha256;
        };

        # Meson build system
        mesonVersion = tools.meson.version;
        mesonSrc = pkgs.fetchzip {
          url = "https://github.com/mesonbuild/meson/releases/download/${mesonVersion}/meson-${mesonVersion}.tar.gz";
          sha256 = tools.meson.sha256;
        };
        # Create wrapper script that invokes meson.py
        mesonDir = pkgs.runCommand "meson-wrapped" {} ''
          mkdir -p $out/bin
          cat > $out/bin/meson << 'WRAPPER'
          #!/bin/sh
          exec python3 /mnt/meson/meson.py "$@"
          WRAPPER
          chmod +x $out/bin/meson
        '';

        # Fetch cloud images (cached in Nix store)
        cloudImages = {
          debian-bookworm = pkgs.fetchurl {
            url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2";
            sha256 = "19irh26rrngw89kr874q2p8bp9yps3ksgnqzvzj93xn3v5mrnb3b";
          };
          # Add more as we get their hashes:
          # debian-trixie = pkgs.fetchurl { ... };
          # ubuntu-noble = pkgs.fetchurl { ... };
          # ubuntu-jammy = pkgs.fetchurl { ... };
        };

        # Distribution configurations
        distros = {
          debian-bookworm = {
            family = "debian";
            codename = "bookworm";
            version = "12";
          };
          # debian-trixie = { family = "debian"; codename = "trixie"; version = "13"; };
          # ubuntu-noble = { family = "ubuntu"; codename = "noble"; version = "24.04"; };
          # ubuntu-jammy = { family = "ubuntu"; codename = "jammy"; version = "22.04"; };
        };

        # Generate VM package for each distro
        mkVm = name: config: vmLib.mkDevVm {
          inherit name llvmDir llvmVersion ninjaDir ninjaVersion cmakeDir cmakeVersion mesonSrc mesonDir mesonVersion;
          inherit (config) family codename version;
          cloudImage = cloudImages.${name};
          hostSharePath = toString self;
        };

        # All VM packages
        vms = builtins.mapAttrs mkVm distros;

      in {
        packages = vms // {
          default = vms.debian-bookworm;
        };

        # Development shell with QEMU and tools
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            qemu
            cloud-utils  # for cloud-localds
            openssh
            coreutils
          ];

          shellHook = ''
            echo "nix.deb development shell"
            echo ""
            echo "Available VMs:"
            echo "  nix build .#debian-bookworm"
            echo "  nix build .#ubuntu-noble"
            echo ""
            echo "After building, run:"
            echo "  ./result/bin/vm run      # Start VM"
            echo "  ./result/bin/vm exec 'command'"
            echo "  ./result/bin/vm snapshot # Save state"
            echo "  ./result/bin/vm restore  # Rollback"
            echo "  ./result/bin/vm stop     # Shutdown"
          '';
        };
      }
    );
}
