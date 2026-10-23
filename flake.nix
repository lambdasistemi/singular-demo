{
  description = "Singular v0.16.0, Demo 1: a shell with singular, open-datum, devnet, the blueprint and the genesis in place";

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
      url = "github:lambdasistemi/singular/v0.16.0";
      flake = false;
    };
    # The three programs, built by the release's own flakes at the same tag.
    offchain.url = "github:lambdasistemi/singular/v0.16.0?dir=offchain";
    open-datum.url = "github:lambdasistemi/singular/v0.16.0?dir=applications/open-datum/offchain";
    # The merged deployment blueprint the release archive carries as onchain/plutus.json.
    open-datum-onchain.url = "github:lambdasistemi/singular/v0.16.0?dir=applications/open-datum/onchain";
    # The package set the kit's helper tools (static jq and curl, the musl C
    # compiler, patchelf) come from: the one the programs themselves are built on.
    nixpkgs.follows = "offchain/nixpkgs";
    # The tutorial stepper that plays demos/demo1 in CI, pinned to its release.
    tutorial-stepper.url = "github:lambdasistemi/tutorial-stepper/v0.4.1";
  };

  outputs =
    {
      self,
      source,
      offchain,
      open-datum,
      open-datum-onchain,
      nixpkgs,
      tutorial-stepper,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      singular = offchain.packages.${system}.singular;
      devnet = offchain.packages.${system}.devnet;
      open-datum-exe = open-datum.packages.${system}.open-datum;
      cardanoNode = offchain.inputs.cardano-node.packages.${system}.cardano-node;
      tutorialStepper = tutorial-stepper.packages.${system}.tutorial-stepper;

      txTools = import ./kit/tx-tools.nix { inherit pkgs; };

      # The static tutorial-stepper binary of its release (checked against
      # that release's SHA256SUMS when the kit is built).
      stepper = import ./kit/stepper.nix { inherit pkgs; };

      # The pay-by-name scenario: its validator and the tools that apply it
      payByName = import ./demos/pay-by-name/build.nix { inherit pkgs; };

      # sink-tools for the development shell: the pay-by-name tools run with the flake's Node.js,
      # as the kit's bin/sink-tools runs them with the kit's Node.js.
      sinkToolsBin = pkgs.writeShellScriptBin "sink-tools" ''
        exec ${pkgs.nodejs-slim}/bin/node ${payByName.tools}/sink-tools.cjs "$@"
      '';

      # The kit's revision, kit/revision: the only place it is written by hand. The release is Singular's and this, as in v0.16.0-1.
      revision = pkgs.lib.removeSuffix "\n" (builtins.readFile ./kit/revision);

      # The Ubuntu kit: tarball plus SHA256SUMS, built from this lock only.
      kit = import ./kit/build.nix {
        inherit
          pkgs
          source
          blueprint
          cardanoNode
          txTools
          ;
        inherit
          singular
          devnet
          revision
          stepper
          ;
        openDatum = open-datum-exe;
        sinkTools = payByName.tools;
        sinkBlueprint = payByName.sink;
        nodejs = pkgs.nodejs-slim;
        payByNamePlay = ./demos/pay-by-name/play;
        payByNameScenario = ./killercoda/pay-by-name-steps;
        demo1Tutorial = ./demos/demo1;
        payByNameTutorial = ./demos/pay-by-name;
        # the Killercoda scenarios are generated from the step files with the scripts of the play
        play = ./demos/demo1/play;
        scenario = ./killercoda/demo1-steps;
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
      contracts = pkgs.runCommand "singular-contracts-v0.16.0" { } ''
        mkdir -p $out
        cp ${blueprint} $out/plutus.json
        cp ${source}/version.txt $out/version.txt
      '';
      # mkdocs with its theme: docs/build.sh builds the documentation site with it
      docs-env = pkgs.symlinkJoin {
        name = "singular-demo-docs-env";
        paths = [
          (pkgs.python3.withPackages (p: [
            p.mkdocs
            p.mkdocs-material
          ]))
          pkgs.nodejs
        ];
      };

      # The tools tools/format.sh and tools/lint.sh need: one set for `nix flake check`, `nix run` and the dev shell.
      lintTools = [
        pkgs.nixfmt
        pkgs.shfmt
        pkgs.shellcheck
        pkgs.biome
        pkgs.ruff
        pkgs.actionlint
        pkgs.nodejs
        pkgs.findutils
        pkgs.diffutils
        pkgs.gnugrep
        pkgs.coreutils
        pkgs.bash
      ];
      # A check runs a script of tools/ on a copy of the repository, so it is the same code that `nix run` runs in a checkout.
      repoCheck =
        name: script:
        pkgs.runCommand name { nativeBuildInputs = lintTools; } ''
          cp -r ${./.} src
          chmod -R u+w src
          cd src
          bash tools/${script}
          touch $out
        '';
      inCheckout =
        name: script:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = lintTools ++ [ pkgs.git ];
          text = ''
            cd "$(git rev-parse --show-toplevel)"
            exec bash tools/${script}
          '';
        };
    in
    {
      packages.${system} = {
        inherit kit kit-verify docs-env;
        tutorial-stepper = tutorialStepper;
        pay-by-name-sink = payByName.sink;
        pay-by-name-tools = payByName.tools;
      };

      apps.${system} = {
        kit-verify = {
          type = "app";
          program = pkgs.lib.getExe kit-verify;
          meta.description = "Checks of the built kit tarball: checksum, no Nix store paths, no RPATH";
        };
        format = {
          type = "app";
          program = pkgs.lib.getExe (inCheckout "format" "format.sh write");
          meta.description = "Format the repository's own files";
        };
        format-check = {
          type = "app";
          program = pkgs.lib.getExe (inCheckout "format-check" "format.sh check");
          meta.description = "Check that the repository's own files are formatted";
        };
        lint = {
          type = "app";
          program = pkgs.lib.getExe (inCheckout "lint" "lint.sh");
          meta.description = "Lint the repository and check that it agrees with itself";
        };
      };

      checks.${system} = {
        format = repoCheck "format" "format.sh check";
        lint = repoCheck "lint" "lint.sh";
        pay-by-name-aiken = payByName.aikenCheck;
        pay-by-name-tools = payByName.tools;
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          name = "singular-demo";
          packages = [
            singular
            open-datum-exe
            devnet
            pkgs.jq
            pkgs.curl
            txTools
            tutorialStepper
            sinkToolsBin
            # The stepper's runtime needs: an interactive bash (readline) and tmux.
            # The shell's plain pkgs.bash has neither; CI has nothing beyond the flake.
            pkgs.bashInteractive
            pkgs.tmux
          ];
          shellHook = ''
            # Where the programs find what they need.
            export blueprint=${contracts}/plutus.json
            export E2E_GENESIS_DIR=${source}/offchain/e2e-test/genesis
            # A short temporary directory: the devnet's node socket path has a length limit.
            export TMPDIR=/tmp/singular-demo-$(id -u)
            mkdir -p -m 700 "$TMPDIR"
            echo "Singular v0.16.0, Demo 1 shell"
            echo "  singular, open-datum, devnet, tx-inspect, tx-diff, jq, curl, tutorial-stepper, sink-tools   on the PATH"
            echo "  \$blueprint          = $blueprint"
            echo "  \$E2E_GENESIS_DIR    = $E2E_GENESIS_DIR"
            echo "  \$TMPDIR             = $TMPDIR"
          '';
        };

        # The shell for working on this repository: the formatters and linters, just, and the documentation tools.
        dev = pkgs.mkShell {
          name = "singular-demo-dev";
          packages = lintTools ++ [
            pkgs.git
            pkgs.just
            pkgs.curl
            pkgs.jq
            pkgs.gh
            docs-env
            tutorialStepper
          ];
        };
      };
    };
}
