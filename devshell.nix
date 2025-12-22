{ pkgs, ... }: pkgs.mkShell {
  packages = with pkgs; [
    qemu
    virtiofsd
    cloud-utils
    openssh
    coreutils
  ];

  shellHook = ''
    echo "nix.deb development shell"
    echo ""
    echo "Available VMs:"
    echo "  nix build .#debian-bookworm"
    echo ""
    echo "After building, run:"
    echo "  ./result/bin/vm run      # Start VM"
    echo "  ./result/bin/vm exec 'command'"
    echo "  ./result/bin/vm snapshot # Save state"
    echo "  ./result/bin/vm restore  # Rollback"
    echo "  ./result/bin/vm stop     # Shutdown"
  '';
}
