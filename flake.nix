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
        llvmVersion = "21.1.8";
        llvmTarball = pkgs.fetchurl {
          url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvmVersion}/LLVM-${llvmVersion}-Linux-X64.tar.xz";
          sha256 = "0avkfnsx2j9vms8mn0rg3jq2bl4l56c76g7amhv0gm8m3n0g5dxk";
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
          inherit name llvmTarball llvmVersion;
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
