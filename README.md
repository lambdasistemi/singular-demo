# Singular Demo 1 shell

A nix shell with everything needed to play Singular's Demo 1 on a private devnet. It builds nothing from source when the binary caches are accepted.

```bash
nix develop github:lambdasistemi/singular-demo --accept-flake-config
```

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

## Limits

- `x86_64-linux` only. Other systems are not built or tested.
- This shell needs Nix on the machine. Running without Nix is not covered here.
