{ pkgs, inputs, perSystem, ... }:
let
  cloudInitDisk = import ../lib/vm-cloud-init {
    inherit pkgs perSystem;
    name = "debian-bookworm";
    family = "debian";
    codename = "bookworm";
  };

  cloudImage = pkgs.fetchurl {
    url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2";
    sha256 = "19irh26rrngw89kr874q2p8bp9yps3ksgnqzvzj93xn3v5mrnb3b";
  };

in import ../lib/vm-script {
  inherit pkgs perSystem cloudInitDisk cloudImage;
  name = "debian-bookworm";
  hostSharePath = toString inputs.self;
}
