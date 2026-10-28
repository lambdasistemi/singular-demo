# Singular demos

Demonstrations of [Singular](https://github.com/lambdasistemi/singular), a registry of keys on Cardano, with tutorials played on private test chains and a separate [recorded journey on Cardano preprod](demo1/preprod.md). Each tutorial brings what it needs.

Every demo can be met in five ways:

- **Read a run.** Each page shows the commands of the demo with what they printed in a real run, made by this repository's continuous integration.
- **Play it in the browser, on Killercoda.** An Ubuntu machine opens in the browser and each command runs with a click.
- **Play it in a Codespace.** The same lessons beside a terminal, in your own GitHub Codespace.
- **Play it in your own terminal, on Linux.** The kit brings the programs, the chain, tmux and tutorial-stepper; `tutorial-stepper play share/tutorials/demo1` plays the same lessons beside the windows of Alice, Bob and the chain.
- **Play it on a Mac, with Homebrew.** `brew tap lambdasistemi/tap`, `brew trust lambdasistemi/tap` (so Homebrew loads the tap's other formulas `singular-demo` depends on), `brew install lambdasistemi/tap/singular-demo`, then `singular-demo` for Demo 1, played with tutorial-stepper's terminal face.

Demo 1 uses v0.17.0.

## The demos

| Demo | What it shows |
|---|---|
| [Demo 1](demo1/index.md) | Carol creates a registry; Alice registers a key, updates its payload and permanently terminates it, with Bob folding the registration and termination. Reclaim an unprocessed registration and clean up an expired one. |
