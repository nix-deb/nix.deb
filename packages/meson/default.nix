{ pkgs, perSystem, ... }:
let
source = pkgs.fetchzip {
  inherit (perSystem.self.tools-json.meson) url hash;
};
in
pkgs.replaceVarsWith {
  src = ./wrapper.sh;
  isExecutable = true;
  dir = "bin";
  replacements = { inherit source; };
}
