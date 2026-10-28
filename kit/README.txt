Singular v0.17.0 demo kit, release v0.17.0-1 (Ubuntu 24.04, x86_64, no Nix needed)
==================================================================

What is in here
  bin/       the programs: singular, open-datum, devnet, cardano-node, the transaction tools
             tx-inspect and tx-diff, plus jq, curl, tmux and tutorial-stepper, and node and
             sink-tools (see below)
  libexec/   the real executables that bin/ starts (do not run these directly)
  lib/       the libraries they run on (the kit brings its own C library)
  share/     the contracts (plutus.json), the devnet's genesis, the packaged data, both
             tutorials (share/tutorials/demo1 and share/tutorials/pay-by-name, played with
             tutorial-stepper), and share/sink-tools/ (see below)
  VERSION    the release tag and commit this kit was built from
  demo.sh    the annotated Demo 1 journey, 16 steps, on a private devnet
  pay-by-name-runtime/  the separately pinned v0.16.0 runtime used only by pay-by-name

Use
  tar xzf singular-demo-v0.17.0-1-x86_64-linux.tar.gz
  cd singular-demo-v0.17.0-1-x86_64-linux
  ./demo.sh                  # runs everything; takes about 8 minutes (two real waits on the chain)

  WORK=/some/folder ./demo.sh             # where vaults, receipts and bundles are kept
                                          # (default: ./singular-demo-run)
  PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
                                          # shorter windows (default 120000 and 60000 milliseconds),
                                          # so the two waits last less; the least allowed values are
                                          # 60000 and 30000, anything lower is refused

The tutorials step by step, in this terminal, with tutorial-stepper: the page beside the
window of the person who acts (carol, alice, bob, or the chain's; in pay-by-name carol, alice,
dave, bob and the chain's). Enter runs the next command in that window and waits until it
is over; s skips a command, c sends it Ctrl-C, n and p turn the page, q closes the page
and keeps the windows. A terminal about 160 columns wide fits both. It takes about
15 minutes. The kit brings tutorial-stepper and tmux; put bin/ first on PATH.
  export PATH="$PWD/bin:$PATH"
  tutorial-stepper play share/tutorials/demo1     # Demo 1, kept in ~/demo1-run
  tutorial-stepper play share/tutorials/pay-by-name  # the pay-by-name story: Carol, Alice,
                                                  # Dave, Bob and the chain, kept in ~/pay-by-name-run
  tutorial-stepper play --auto share/tutorials/demo1 --path short --run ./demo1-run \
      --run-setup --transcript ./transcript.toml  # Demo 1 unattended, shortest windows
                                                  # (60 s and 30 s), so the two waits last less
  tutorial-stepper play share/tutorials/demo1     # again: back to the same windows and page

The tools of the pay-by-name scenario: bin/sink-tools applies the sink validator to a name, checks a registry, pays a
sink and moves money out of it. It is JavaScript in one file, share/sink-tools/sink-tools.cjs, with the compiled
sink validator inside and again beside it as share/sink-tools/plutus.json. It runs on the kit's own Node.js, bin/node,
which starts through the kit's own C library like the other programs; the machine needs no node of its own.
  bin/sink-tools                          # lists its commands

The programs also work on their own: put bin/ first on PATH
  export PATH="$PWD/bin:$PATH"
  singular --help
  open-datum --help

The transaction tools (cardano-tx-tools 0.2.3.0) read a transaction in the TextEnvelope shape
(a file holding type, description and cborHex). Every transaction in a bundle carries one:
  jq '.transactions[0].envelope' singular-demo-run/bob/bundles/fold-dave.bundle > tx.envelope
  tx-inspect tx.envelope                # a tree: inputs, outputs, fee, validity interval, ...
  tx-diff a.envelope b.envelope         # what differs between two transactions

Needs: a 64-bit Linux with kernel 3.10 or newer, bash, and the usual base tools
(coreutils, sed, grep, awk, util-linux for setsid). No Nix, no Docker, no root, no
FUSE, no user namespaces. Nothing is installed outside the folder you unpacked.

Everything here is a private test chain. Nothing touches a public network.

Demo 1 uses v0.17.0. Pay-by-name stays on v0.16.0 until the new release can read a key (Singular issue 744).
Termination is permanent and donates the protected deposit to the treasury. The receipts do not independently read current registry state.
