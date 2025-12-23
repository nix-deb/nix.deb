{ pkgs, inputs, ... }:

# This produces the same input every time.
# If we make the comment something like `${baseNameOf inputs.self}` it'll change more frequently.
pkgs.runCommand "vm-ssh-key" {} ''
  mkdir -p $out
  ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f $out/id_ed25519 -N "" -C "nix-deb-vm"
''
