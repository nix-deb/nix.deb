{ pkgs, perSystem, ... }:

pkgs.lib.makeOverridable (
  { name }:
  let
    userData = pkgs.replaceVars ./user-data.yml {
      hostname = name;
      ssh-key = builtins.readFile "${perSystem.self.vm-ssh-key}/id_ed25519.pub";
      inherit (perSystem.self)
        llvm
        ninja
        cmake
        meson
        ;
    };
    metaData = pkgs.writeText "meta-data" ''
      instance-id: ${name}
      local-hostname: ${name}
    '';
  in
  pkgs.runCommand "cloud-init-${name}"
    {
      nativeBuildInputs = [ pkgs.cloud-utils ];
    }
    ''
      mkdir -p $out
      cloud-localds $out/seed.img ${userData} ${metaData}
    ''
)
