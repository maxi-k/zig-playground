{ pkgs ? import <nixpkgs> {}, ... }:

with pkgs;
stdenv.mkDerivation {
  name = "zig-playground";
  version = "0.1.0";

  buildInputs = [
    zig
    zls
  ];
}
