{ pkgs, perSystem, ... }:
pkgs.fetchzip {
  inherit (perSystem.self.tools-json.meson) url hash;
}
