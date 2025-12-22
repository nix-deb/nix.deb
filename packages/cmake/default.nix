{ pkgs, perSystem, ... }:
pkgs.fetchzip {
  inherit (perSystem.self.tools-json.cmake) url hash;
}
