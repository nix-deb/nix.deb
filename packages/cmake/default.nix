{ pkgs, ... }:
let
  tools = builtins.fromJSON (builtins.readFile ../../tools.json);
in pkgs.fetchzip {
  url = tools.cmake.url;
  hash = tools.cmake.hash;
}
