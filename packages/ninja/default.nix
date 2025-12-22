{ pkgs, ... }:
let
  tools = builtins.fromJSON (builtins.readFile ../../tools.json);
  ninjaSrc = pkgs.fetchzip {
    url = tools.ninja.url;
    hash = tools.ninja.hash;
    stripRoot = false;
  };
in pkgs.runCommand "ninja-wrapped" {} ''
  mkdir -p $out/bin
  cp ${ninjaSrc}/ninja $out/bin/
  chmod +x $out/bin/ninja
''
