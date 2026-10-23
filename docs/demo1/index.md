# Demo 1

Alice and Bob keep a registry of keys on a private Cardano test chain. A key is booked, folded into the registry, read back, changed and removed. A request nobody folds is rejected, and another is taken back by its owner. The page [Where this design stops](tutorial.md) says what the demo does not show.

## Read a run

- [A run](run.md): the steps of the tutorial, each command followed by what it printed.
- [The annotated script, as it ran](script-run.md): the kit's own narrated script, the 16 steps in one log.
- [The tutorial](tutorial.md): the same steps without results, to copy from. [A page with bigger buttons](interactive.html) keeps a done mark for each step.

## Play it

- **Killercoda**, in the browser: the course `Singular demos`, https://killercoda.com/paolino/course/killercoda, with the tutorial step by step (https://killercoda.com/paolino/course/killercoda/demo1-steps) and the kit's annotated script (https://killercoda.com/paolino/course/killercoda/demo1-script)
- **Codespaces**: https://codespaces.new/lambdasistemi/singular-demo?quickstart=1
- **On your own Ubuntu**: download the kit from the [latest release](https://github.com/lambdasistemi/singular-demo/releases/latest), check it against `SHA256SUMS`, unpack it and run `./demo.sh`.
- **In your own terminal, on Linux x86_64**: download the kit from the [daily release](https://github.com/lambdasistemi/singular-demo/releases/tag/daily), check it against `SHA256SUMS`, unpack it, put its `bin/` on `PATH` and run `tutorial-stepper play share/tutorials/demo1`: the tutorial step by step, the page beside the tmux windows of Alice, Bob and the chain, each command run with Enter.
- **On a Mac, with Homebrew**: `brew install lambdasistemi/tap/singular-demo`, then `singular-demo`: Demo 1 step by step with tutorial-stepper, the page beside the tmux windows of Alice, Bob and the chain.
