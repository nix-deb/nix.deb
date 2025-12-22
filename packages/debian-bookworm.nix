{ pkgs, inputs, perSystem, ... }:
let
  tools = perSystem.self.tools-json;
  vmLib = import ./vm { inherit pkgs; };
  cloudImage = pkgs.fetchurl {
    url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2";
    sha256 = "19irh26rrngw89kr874q2p8bp9yps3ksgnqzvzj93xn3v5mrnb3b";
  };
in vmLib.mkDevVm {
  name = "debian-bookworm";
  family = "debian";
  codename = "bookworm";
  version = "12";
  inherit cloudImage;
  hostSharePath = toString inputs.self;
  llvmSrc = perSystem.self.llvm;
  llvmVersion = tools.llvm.version;
  ninjaDir = perSystem.self.ninja;
  ninjaVersion = tools.ninja.version;
  cmakeDir = perSystem.self.cmake;
  cmakeVersion = tools.cmake.version;
  mesonSrc = perSystem.self.meson;
  mesonVersion = tools.meson.version;
}
