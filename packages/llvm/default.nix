{ pkgs, ... }:
let
  tools = builtins.fromJSON (builtins.readFile ../../tools.json);
in pkgs.fetchzip {
  url = tools.llvm.url;
  hash = tools.llvm.hash;
}
