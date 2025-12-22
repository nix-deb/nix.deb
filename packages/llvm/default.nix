{ pkgs, perSystem, ... }:
pkgs.fetchzip {
  inherit (perSystem.self.tools-json.llvm) url hash;
}
