{ pkgs, inputs, perSystem, ... }:
import ./debian-bookworm.nix { inherit pkgs inputs perSystem; }
