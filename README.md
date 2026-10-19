# Singular Demo 1 shell

A nix shell with everything needed to play Singular's Demo 1 on a private devnet. It builds nothing from source when the binary caches are accepted.

```bash
nix develop github:lambdasistemi/singular-demo --accept-flake-config
```

## Step by step

The whole journey is written as steps to paste into one terminal: one command per block, the explanation as text above it, passphrases typed at the prompt.

- https://lambdasistemi.github.io/singular-demo/ is a page with a Copy button on each block and a done mark per step. Every copy ends with a line return, so the last command runs when pasted.
- [DEMO.md](DEMO.md) holds the same steps in this repository. GitHub puts a copy button on each block.

An automatic test, `runbook/test.sh`, pastes every block in order into one shell against a fresh devnet and checks the receipts: all 16 steps pass.

## What is inside

The shell is Singular release v0.12.0.

| In the shell | What it is |
|---|---|
| `singular`, `open-datum` | the two command-line programs of the release |
| `devnet` | starts a private Cardano devnet with a Koios-style HTTP API, and funds the addresses given to it |
| `jq` | to read the JSON receipts |
| `$blueprint` | the compiled validators the commands take as `--blueprint` (the release archive's `onchain/plutus.json`, same bytes) |
| `$E2E_GENESIS_DIR` | the genesis files `devnet` starts its node from |
| `$TMPDIR` | `/tmp/singular-demo-<uid>`, short because the node's socket path length is limited |

`devnet` starts a `cardano-node` 10.7.0 of its own; it is part of the devnet program's closure.

The journey itself is `DEMO1.md` in the release archive:

https://github.com/lambdasistemi/singular/releases/tag/v0.12.0

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

On a multi-user nix install a user that is not in `trusted-users` cannot add substituters from a flake, even with `--accept-flake-config`. Then either add the user to `trusted-users` in `/etc/nix/nix.conf`, or list the two caches under `trusted-substituters` and keep the command as it is.

## Without Nix: the Ubuntu kit

A tarball for Ubuntu 24.04 on x86_64 carries the same programs, their libraries, the devnet's node and an annotated script of the whole journey. It needs no Nix, no Docker and no root, and installs nothing outside its folder.

```bash
curl -fLO https://github.com/lambdasistemi/singular-demo/releases/download/v0.12.0/singular-demo-v0.12.0-x86_64-linux.tar.gz
curl -fLO https://github.com/lambdasistemi/singular-demo/releases/download/v0.12.0/SHA256SUMS
sha256sum -c SHA256SUMS
tar xzf singular-demo-v0.12.0-x86_64-linux.tar.gz
cd singular-demo-v0.12.0-x86_64-linux
./demo.sh
```

`./demo.sh` runs the 16 steps on a private devnet and takes about 8 minutes, two of them real waits on the chain. Everything is a private test chain; nothing touches a public network.

- `STEP_PAUSE=yes ./demo.sh` waits for Enter between steps.
- `DEVNET_MODE=other-terminal ./demo.sh` leaves the devnet to a second terminal.
- `WORK=/some/folder ./demo.sh` chooses where vaults, receipts and bundles are kept.

The kit was run in a clean `ubuntu:24.04` container with no `/nix`: exit 0, all 16 steps. A kit with one library removed fails, as it should. It was not independently audited.

## Limits

- The nix shell is `x86_64-linux` only. Other systems are not built or tested.
- The kit is Ubuntu 24.04 on x86_64. Other distributions and ARM are not tested.
