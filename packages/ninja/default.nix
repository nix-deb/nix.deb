{ pkgs, perSystem, ... }:
pkgs.fetchzip {
  inherit (perSystem.self.tools-json.ninja) url hash;
  stripRoot = false;
  postFetch = ''
    mkdir -p $out/bin
    mv $out/ninja $out/bin/
  '';
}
