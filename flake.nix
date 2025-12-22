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

        # LLVM/Clang toolchain (single version for all distros)
        # Pre-extracted in Nix store, shared via 9P to VMs
        llvmVersion = "21.1.8";
        llvmSrc = pkgs.fetchzip {
          url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvmVersion}/LLVM-${llvmVersion}-Linux-X64.tar.xz";
          sha256 = "12g4p8zr4yff8l6pgpr4d3aalzflv5f1jh5pnlh8p778kay5azgk";
        };
        # Dereference symlinks for 9P sharing (9P can't follow symlinks)
        llvmDir = pkgs.runCommand "llvm-dereferenced" {} ''
          cp -rL ${llvmSrc} $out
        '';

        # Ninja build system (newer than distro packages)
        ninjaVersion = "1.13.2";
        ninjaSrc = pkgs.fetchzip {
          url = "https://github.com/ninja-build/ninja/releases/download/v${ninjaVersion}/ninja-linux.zip";
          sha256 = "sha256-DKUkXZEIAjZ4KSajXfvDMqQlEEq8mt2v8Yd9Ly73F1A=";
          stripRoot = false;
        };
        # Wrap in bin/ directory for consistent structure
        ninjaDir = pkgs.runCommand "ninja-wrapped" {} ''
          mkdir -p $out/bin
          cp ${ninjaSrc}/ninja $out/bin/
          chmod +x $out/bin/ninja
        '';

        # CMake (newer than distro packages)
        cmakeVersion = "4.2.1";
        cmakeDir = pkgs.fetchzip {
          url = "https://github.com/Kitware/CMake/releases/download/v${cmakeVersion}/cmake-${cmakeVersion}-linux-x86_64.tar.gz";
          sha256 = "1pbh3fs92l3smcnv0qn39lbhl7awl2vnqmj2fgmk88in4ra0k5nc";
        };

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
          inherit name llvmDir llvmVersion ninjaDir ninjaVersion cmakeDir cmakeVersion;
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
