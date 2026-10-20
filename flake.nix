{
  description = "Singular v0.13.1, Demo 1: a shell with singular, open-datum, devnet, the blueprint and the genesis in place";

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
      url = "github:lambdasistemi/singular/v0.13.1";
      flake = false;
    };
    # The three programs, built by the release's own flakes at the same tag.
    offchain.url = "github:lambdasistemi/singular/v0.13.1?dir=offchain";
    open-datum.url = "github:lambdasistemi/singular/v0.13.1?dir=applications/open-datum/offchain";
    # The merged deployment blueprint the release archive carries as onchain/plutus.json.
    open-datum-onchain.url = "github:lambdasistemi/singular/v0.13.1?dir=applications/open-datum/onchain";
    # The package set the kit's helper tools (static jq and curl, the musl C
    # compiler, patchelf) come from: the one the programs themselves are built on.
    nixpkgs.follows = "offchain/nixpkgs";
  };

  outputs =
    {
      self,
      source,
      offchain,
      open-datum,
      open-datum-onchain,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      singular = offchain.packages.${system}.singular;
      devnet = offchain.packages.${system}.devnet;
      open-datum-exe = open-datum.packages.${system}.open-datum;
      cardanoNode = offchain.inputs.cardano-node.packages.${system}.cardano-node;

      txTools = import ./kit/tx-tools.nix { inherit pkgs; };

      # The Ubuntu kit: tarball plus SHA256SUMS, built from this lock only.
      kit = import ./kit/build.nix {
        inherit pkgs source blueprint cardanoNode txTools;
        inherit singular devnet;
        openDatum = open-datum-exe;
      };

      # Checks of the built tarball's contents (no container needed).
      kit-verify = pkgs.writeShellApplication {
        name = "kit-verify";
        runtimeInputs = [
          pkgs.binutils
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnutar
          pkgs.gzip
        ];
        text = ''
          export KIT_DIR=${kit}
          exec ${pkgs.bash}/bin/bash ${./kit/verify.sh} "$@"
        '';
      };
      blueprint = open-datum-onchain.packages.${system}.open-datum-blueprint;
      # The commands look for version.txt beside the contracts file, so the two travel together.
      contracts = pkgs.runCommand "singular-contracts-v0.13.1" { } ''
        mkdir -p $out
        cp ${blueprint} $out/plutus.json
        cp ${source}/version.txt $out/version.txt
      '';
    in
    {
      packages.${system} = {
        inherit kit kit-verify;
      };

      apps.${system}.kit-verify = {
        type = "app";
        program = pkgs.lib.getExe kit-verify;
      };

      devShells.${system}.default = pkgs.mkShell {
        name = "singular-demo";
        packages = [
          singular
          open-datum-exe
          devnet
          pkgs.jq
          txTools
        ];
        shellHook = ''
          # Where the programs find what they need.
          export blueprint=${contracts}/plutus.json
          export E2E_GENESIS_DIR=${source}/offchain/e2e-test/genesis
          # A short temporary directory: the devnet's node socket path has a length limit.
          export TMPDIR=/tmp/singular-demo-$(id -u)
          mkdir -p -m 700 "$TMPDIR"
          echo "Singular v0.13.1, Demo 1 shell"
          echo "  singular, open-datum, devnet, tx-inspect, tx-diff, jq   on the PATH"
          echo "  \$blueprint          = $blueprint"
          echo "  \$E2E_GENESIS_DIR    = $E2E_GENESIS_DIR"
          echo "  \$TMPDIR             = $TMPDIR"
        '';
      };
    };
}
