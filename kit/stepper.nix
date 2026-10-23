# tutorial-stepper of lambdasistemi/tutorial-stepper: the project's own static
# release executable, fetched as a fixed-output derivation (a download checked
# against a hash, no compilation). The hash is the x86_64-linux line of the
# release's SHA256SUMS asset, kept beside this file as
# kit/tutorial-stepper.SHA256SUMS; kit/build.nix refuses a binary that does
# not match it.
{ pkgs }:
let
  version = "0.4.1";
in
pkgs.fetchurl {
  url = "https://github.com/lambdasistemi/tutorial-stepper/releases/download/v${version}/tutorial-stepper-${version}-x86_64-linux";
  sha256 = "8dfd712fa89fed9b33c7e4d359cceca1618054dc3c1e4240b07cf077c408d5d4";
}
