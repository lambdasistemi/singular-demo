# tx-inspect and tx-diff of lambdasistemi/cardano-tx-tools: the project's own
# static musl release executables, fetched as fixed-output derivations (a
# download checked against a hash, no compilation). The hashes are the ones in
# the release's SHA256SUMS asset.
{ pkgs }:
let
  version = "0.2.3.0";
  fetch =
    name: sha256:
    pkgs.fetchurl {
      url = "https://github.com/lambdasistemi/cardano-tx-tools/releases/download/v${version}/${name}-${version}-x86_64-linux-musl.tar.gz";
      inherit sha256;
    };
  tx-inspect = fetch "tx-inspect" "f5254b6759cff9df35c8197941d0f20e1243676fa6f633a5c5b66cb17f7dafca";
  tx-diff = fetch "tx-diff" "6f4eb994ae59b3a201e4633ac1416d2109414116095be78775d0f961d9ae863a";
in
pkgs.runCommand "cardano-tx-tools-${version}" { } ''
  mkdir -p $out/bin
  tar xzf ${tx-inspect} -C $out/bin tx-inspect
  tar xzf ${tx-diff} -C $out/bin tx-diff
''
