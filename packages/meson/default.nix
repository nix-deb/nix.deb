{ pkgs, ... }:
let
  tools = builtins.fromJSON (builtins.readFile ../../tools.json);
in pkgs.fetchzip {
  url = tools.meson.url;
  hash = tools.meson.hash;
}
