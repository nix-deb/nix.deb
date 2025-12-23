{ pkgs, inputs, perSystem, ... }:

perSystem.self.vm-script {
  name = "debian-bookworm";
  cloudImage = pkgs.fetchurl {
    url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2";
    sha256 = "19irh26rrngw89kr874q2p8bp9yps3ksgnqzvzj93xn3v5mrnb3b";
  };

  hostSharePath = toString inputs.self;
}
