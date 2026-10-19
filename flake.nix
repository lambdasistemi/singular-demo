{
  description = "Singular v0.12.0, Demo 1: a shell with singular, open-datum, devnet, the blueprint and the genesis in place";

  # Binary caches. The programs are built by the project's CI and pushed to
  # paolino.cachix.org (public); cardano-node is also in cache.iog.io. Without
  # these, nix compiles the whole Haskell stack on the user's machine.
  nixConfig = {
    extra-substituters = [
      "https://paolino.cachix.org"
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "paolino.cachix.org-1:ecmgO3CXdgSWA2cHlm4srknd/cLFMLmK3i3NrzeDFaE="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };

  inputs = {
    # The tagged source tree: the devnet's genesis files live in it.
    source = {
      url = "github:lambdasistemi/singular/v0.12.0";
      flake = false;
    };
    # The three programs, built by the release's own flakes at the same tag.
    offchain.url = "github:lambdasistemi/singular/v0.12.0?dir=offchain";
    open-datum.url = "github:lambdasistemi/singular/v0.12.0?dir=applications/open-datum/offchain";
    # The merged deployment blueprint the release archive carries as onchain/plutus.json.
    open-datum-onchain.url = "github:lambdasistemi/singular/v0.12.0?dir=applications/open-datum/onchain";
  };

  outputs =
    {
      self,
      source,
      offchain,
      open-datum,
      open-datum-onchain,
    }:
    let
      system = "x86_64-linux";
      pkgs = offchain.inputs.nixpkgs.legacyPackages.${system};
      singular = offchain.packages.${system}.singular;
      devnet = offchain.packages.${system}.devnet;
      open-datum-exe = open-datum.packages.${system}.open-datum;
      blueprint = open-datum-onchain.packages.${system}.open-datum-blueprint;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "singular-demo";
        packages = [
          singular
          open-datum-exe
          devnet
          pkgs.jq
        ];
        shellHook = ''
          # Where the programs find what they need.
          export blueprint=${blueprint}
          export E2E_GENESIS_DIR=${source}/offchain/e2e-test/genesis
          # A short temporary directory: the devnet's node socket path has a length limit.
          export TMPDIR=/tmp/singular-demo-$(id -u)
          mkdir -p -m 700 "$TMPDIR"
          echo "Singular v0.12.0, Demo 1 shell"
          echo "  singular, open-datum, devnet, jq   on the PATH"
          echo "  \$blueprint          = $blueprint"
          echo "  \$E2E_GENESIS_DIR    = $E2E_GENESIS_DIR"
          echo "  \$TMPDIR             = $TMPDIR"
        '';
      };
    };
}
