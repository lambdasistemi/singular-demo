Singular v0.13.0 demo kit (Ubuntu 24.04, x86_64, no Nix needed)
==================================================================

What is in here
  bin/       the programs: singular, open-datum, devnet, cardano-node, the transaction tools
             tx-inspect and tx-diff, plus jq and curl
  libexec/   the real executables that bin/ starts (do not run these directly)
  lib/       the libraries they run on (the kit brings its own C library)
  share/     the contracts (plutus.json), the devnet's genesis and the packaged data
  VERSION    the release tag and commit this kit was built from
  demo.sh    the annotated Demo 1 journey, 16 steps, on a private devnet

Use
  tar xzf singular-demo-v0.13.0-x86_64-linux.tar.gz
  cd singular-demo-v0.13.0-x86_64-linux
  ./demo.sh                  # runs everything; takes about 8 minutes (two real waits on the chain)

  DEVNET_MODE=other-terminal ./demo.sh    # you start the devnet in a second terminal
  STEP_PAUSE=yes ./demo.sh                # press Enter between steps
  WORK=/some/folder ./demo.sh             # where vaults, receipts and bundles are kept
                                          # (default: ./singular-demo-run)
  PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
                                          # shorter windows (default 120000 and 60000 milliseconds),
                                          # so the two waits last less; the least allowed values are
                                          # 60000 and 30000, anything lower is refused

The programs also work on their own: put bin/ first on PATH
  export PATH="$PWD/bin:$PATH"
  singular --help
  open-datum --help

The transaction tools (cardano-tx-tools 0.2.3.0) read a transaction in the TextEnvelope shape
(a file holding type, description and cborHex). Every transaction in a bundle carries one:
  jq '.transactions[0].envelope' singular-demo-run/bundles/fold-dave.bundle > tx.envelope
  tx-inspect tx.envelope                # a tree: inputs, outputs, fee, validity interval, ...
  tx-diff a.envelope b.envelope         # what differs between two transactions

Needs: a 64-bit Linux with kernel 3.10 or newer, bash, and the usual base tools
(coreutils, sed, grep, awk, util-linux for setsid). No Nix, no Docker, no root, no
FUSE, no user namespaces. Nothing is installed outside the folder you unpacked.

Everything here is a private test chain. Nothing touches a public network.
