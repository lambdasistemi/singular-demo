# Singular demos

Demonstrations of [Singular](https://github.com/lambdasistemi/singular), a registry of keys on Cardano, played on a private test chain. Nothing here touches a public network. The Singular release used is v0.13.1.

## Demo 1: Alice and Bob keep a registry

A key is booked, folded into the registry, read back, changed and removed. A request nobody folds is rejected, and another is taken back by its owner. There are three ways to meet it.

**Read a run.** Every command of the tutorial with what it printed in a real run, made by this repository's continuous integration:

https://lambdasistemi.github.io/singular-demo/demo1/run/

**Play it in the browser, on Killercoda.** An Ubuntu machine opens in the browser, with nothing to install, and each command runs with a click. The scenarios are in the course `Singular demos`:

https://killercoda.com/paolino/course/killercoda

The tutorial step by step, as Alice and as Bob in two tmux windows: https://killercoda.com/paolino/course/killercoda/demo1-steps

The kit's annotated script, run in one go: https://killercoda.com/paolino/course/killercoda/demo1-script

**Play it in a Codespace.** The same lessons beside a terminal, in your own GitHub Codespace (it uses your own Codespaces quota):

https://codespaces.new/lambdasistemi/singular-demo?quickstart=1

The documentation site, with the tutorial, the runs and the annotated script as it ran, is https://lambdasistemi.github.io/singular-demo/

## On your own machine

**With Nix**, one command opens a shell with `singular`, `open-datum`, `devnet` and `jq`, and the tutorial's steps can be pasted into it:

```bash
nix develop github:lambdasistemi/singular-demo --accept-flake-config
```

**Without Nix**, on Ubuntu 24.04 (x86_64): a kit with the same programs, their libraries, the devnet's node and an annotated script of the whole journey. It needs no Nix, no Docker and no root, and installs nothing outside its folder.

```bash
version=v0.13.1
curl -fLO https://github.com/lambdasistemi/singular-demo/releases/download/$version/singular-demo-$version-x86_64-linux.tar.gz
curl -fLO https://github.com/lambdasistemi/singular-demo/releases/download/$version/SHA256SUMS
sha256sum -c SHA256SUMS
tar xzf singular-demo-$version-x86_64-linux.tar.gz
cd singular-demo-$version-x86_64-linux
./demo.sh
```

`./demo.sh` runs the 16 steps on a private devnet and takes about 8 minutes, two of them real waits on the chain.

- `STEP_PAUSE=yes ./demo.sh` waits for Enter between steps.
- `DEVNET_MODE=other-terminal ./demo.sh` leaves the devnet to a second terminal.
- `WORK=/some/folder ./demo.sh` chooses where vaults, receipts and bundles are kept.
- `PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh` shortens the registry's two windows, and the waits with them.

## What the repository delivers, and how it is checked

| What | Where it comes from | What checks it |
|---|---|---|
| The Ubuntu kit, a release for each Singular version | `nix build .#kit` from `flake.lock`; a pushed tag `vX.Y.Z` publishes it | the build, `kit-verify`, `demo.sh` in a clean Ubuntu container with no Nix and no network, and failing controls |
| The tutorial and the runs | `demos/demo1/s*.md`, run by `demos/demo1/test.sh` against a fresh devnet | the receipts of all 16 steps; the log of the run becomes the page `run` |
| The Killercoda scenarios | generated into `killercoda/` by `node demos/demo1/killercoda.js .` | the generated files must equal the committed ones, and a scenario test plays them in a clean Ubuntu with real tmux windows |
| The Codespaces tutorial | `.devcontainer/` and `tutorial/`; it plays the same scenario | its own tests, in a browser, up to the whole demo through the buttons |
| The documentation site | `mkdocs.yml`, `docs/`, built by `docs/build.sh` | the site is built from the logs of the same run |

Killercoda and Codespaces run the same scripts of the play, in `demos/demo1/play/`: install the kit, make the folders, set up the shell, start the windows.

A new demo is a folder `demos/demoN/` beside `demo1`, with its steps, its generator and its tests, and a page in `docs/`.

## Working on this repository

```bash
nix develop .#dev --command just ci
```

`just ci` formats nothing and changes nothing: it checks the formatting of every file we write (`nixfmt`, `shfmt`, `biome`, `ruff`), lints them (`shellcheck`, `biome`, `ruff`, `actionlint`), checks that the committed Killercoda scenarios are the ones the step files generate and that this README names the pinned Singular version, and builds the flake checks. `just format` fixes the formatting; `just generate` regenerates the scenarios. The tutorial is edited only in `demos/demo1/s*.md` and its generators, never in `killercoda/`.

A pull request runs, on the self-hosted `nixos` runners after a Build Gate, the flake checks, the kit build and its checks, and the tutorial against a fresh devnet, and the documentation build. It runs on a GitHub-hosted Ubuntu the three jobs that need a real Ubuntu with Docker: the kit in a clean container with no Nix and no network, the Killercoda scenarios and the Codespaces tutorial. A push to main publishes the daily release and the site; a tag `vX.Y.Z`, which must name the pinned Singular version, publishes the numbered release. Commits follow Conventional Commits and pull requests use the template in `.github/`.

## Binary caches

The programs are built by the project's CI and stored in a public Cachix cache. The flake names its caches in `nixConfig`:

- https://paolino.cachix.org
- https://cache.iog.io

Measured from an empty store with only `cache.nixos.org` configured:

| | derivations built | paths fetched | download |
|---|---|---|---|
| flake caches accepted | 1 (the shell itself) | 144 | 190 MiB |
| flake caches not accepted | 1110 | 710 | 1080 MiB |

Without the caches nix compiles the Haskell stack on the machine. Accept the flake configuration, as in the command above.

On a multi-user nix install a user that is not in `trusted-users` cannot add substituters from a flake, even with `--accept-flake-config`. Then either add the user to `trusted-users` in `/etc/nix/nix.conf`, or list the two caches under `trusted-substituters` and accept the flake configuration.

## Limits

- The nix shell is `x86_64-linux` only. Other systems are not built or tested.
- The kit is Ubuntu 24.04 on x86_64. Other distributions and ARM are not tested.
- The kit was run in a clean `ubuntu:24.04` container with no `/nix`, and a kit with one library removed fails, as it should. It was not independently audited.
