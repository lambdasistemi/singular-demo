# Demo 1

Carol creates a registry on a private Cardano chain. Alice registers a key, changes its payload and permanently terminates it; Bob folds the registration and termination. An expired registration is cleaned up, and another is reclaimed by its requester. Demo 1 uses v0.19.0. After each change, Alice or Bob reads the key back from the chain with `open-datum inspect` or `singular registry inspect`. The page [Where this design stops](tutorial.md) says what the demo does not show.

## Read a run

- [A run](run.md): the steps of the tutorial, each command followed by what it printed.
- [The annotated script, as it ran](script-run.md): the kit's own narrated script, the 16 steps in one log.
- [The tutorial](tutorial.md): the same steps without results, to copy from. [A page with bigger buttons](interactive.html) keeps a done mark for each step.

## Play it

- **Killercoda**, in the browser: the course `Singular demos`, https://killercoda.com/paolino/course/killercoda, with the tutorial step by step (https://killercoda.com/paolino/course/killercoda/demo1-steps) and the kit's annotated script (https://killercoda.com/paolino/course/killercoda/demo1-script)
- **Codespaces**: https://codespaces.new/lambdasistemi/singular-demo?quickstart=1
- **On your own Ubuntu**: download the kit from the [latest release](https://github.com/lambdasistemi/singular-demo/releases/latest), check it against `SHA256SUMS`, unpack it and run `./demo.sh`. It asks whether to run straight through or to pause before each step (`DEMO_MODE=continuous` or `DEMO_MODE=pause` chooses without the question). In pause mode, steps 4, 13 and 16 run without a pause, because a booking must be folded before its processing deadline.
- **In your own terminal, on Linux x86_64**: download the kit from the [daily release](https://github.com/lambdasistemi/singular-demo/releases/tag/daily), check it against `SHA256SUMS`, unpack it, put its `bin/` on `PATH` and run `tutorial-stepper play share/tutorials/demo1`: the tutorial step by step, the page beside the tmux windows of Alice, Bob and the chain, each command run with Enter.
- **On a Mac, with Homebrew**: `brew tap lambdasistemi/tap`, `brew trust lambdasistemi/tap` (so Homebrew loads the tap's other formulas `singular-demo` depends on), `brew install lambdasistemi/tap/singular-demo`, then `singular-demo`: Demo 1 step by step with tutorial-stepper, the page beside the tmux windows of Alice, Bob and the chain.
