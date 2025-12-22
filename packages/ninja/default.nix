{ pkgs, perSystem, ... }:
let
  ninjaSrc = pkgs.fetchzip {
    inherit (perSystem.self.tools-json.ninja) url hash;
    stripRoot = false;
  };
in pkgs.runCommand "ninja-wrapped" {} ''
  mkdir -p $out/bin
  cp ${ninjaSrc}/ninja $out/bin/
  chmod +x $out/bin/ninja
''
