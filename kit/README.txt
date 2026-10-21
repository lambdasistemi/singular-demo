Singular v0.14.0 demo kit, release v0.14.0-1 (Ubuntu 24.04, x86_64, no Nix needed)
==================================================================

What is in here
  bin/       the programs: singular, open-datum, devnet, cardano-node, the transaction tools
             tx-inspect and tx-diff, plus jq, curl and tmux, and node and sink-tools (see below)
  libexec/   the real executables that bin/ starts (do not run these directly)
  lib/       the libraries they run on (the kit brings its own C library)
  share/     the contracts (plutus.json), the devnet's genesis, the packaged data, the pages
             and the window setup drive.sh plays, and share/sink-tools/ (see below)
  VERSION    the release tag and commit this kit was built from
  demo.sh    the annotated Demo 1 journey, 16 steps, on a private devnet
  drive.sh   the same journey as a tutorial you play step by step, as Alice and as Bob, in tmux windows;
             ./drive.sh pay-by-name plays the pay-by-name story, in the windows of five people

Use
  tar xzf singular-demo-v0.14.0-1-x86_64-linux.tar.gz
  cd singular-demo-v0.14.0-1-x86_64-linux
  ./demo.sh                  # runs everything; takes about 8 minutes (two real waits on the chain)

  DEVNET_MODE=other-terminal ./demo.sh    # you start the devnet in a second terminal
  STEP_PAUSE=yes ./demo.sh                # press Enter between steps
  WORK=/some/folder ./demo.sh             # where vaults, receipts and bundles are kept
                                          # (default: ./singular-demo-run)
  PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
                                          # shorter windows (default 120000 and 60000 milliseconds),
                                          # so the two waits last less; the least allowed values are
                                          # 60000 and 30000, anything lower is refused

The tutorial step by step, in this terminal: the page on the left and, beside it, the window
of the person who acts (alice, bob, or the chain's; in pay-by-name carol, alice, dave, bob and the chain's). Enter types the next command into that window
and waits until it is over; s skips a command, c sends it Ctrl-C, n and p turn the page, q closes
the page. A terminal about 160 columns wide fits both. It takes about 15 minutes.
  ./drive.sh                              # Demo 1
  ./drive.sh pay-by-name                  # the pay-by-name story: Carol, Alice, Dave, Bob and the chain
  WORK=/some/folder ./drive.sh            # where the run's files are kept (default: ~/singular-demo-run, and
                                          # ~/singular-pay-by-name-run for pay-by-name); the folder of an
                                          # earlier run is moved aside, never deleted
  PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./drive.sh
                                          # Demo 1 only: shorter windows, as for demo.sh (the tutorial writes
                                          # 180000 and 60000), so the two waits last less
  ./drive.sh                              # again: back to the same windows and page
  bin/tmux -L singular-demo kill-server           # ends the windows of Demo 1
  bin/tmux -L singular-pay-by-name kill-server    # ends the windows of pay-by-name

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
  jq '.transactions[0].envelope' singular-demo-run/bundles/fold-dave.bundle > tx.envelope
  tx-inspect tx.envelope                # a tree: inputs, outputs, fee, validity interval, ...
  tx-diff a.envelope b.envelope         # what differs between two transactions

Needs: a 64-bit Linux with kernel 3.10 or newer, bash, and the usual base tools
(coreutils, sed, grep, awk, util-linux for setsid). No Nix, no Docker, no root, no
FUSE, no user namespaces. Nothing is installed outside the folder you unpacked.

Everything here is a private test chain. Nothing touches a public network.
