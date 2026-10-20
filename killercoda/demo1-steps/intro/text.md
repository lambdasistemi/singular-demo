Singular keeps a registry of keys on Cardano. Here you play its Demo 1 yourself on a **private test chain**: nothing touches a public network, and nothing is installed on this machine. The project is at https://github.com/lambdasistemi/singular and its documentation at https://lambdasistemi.github.io/singular/ ; its own page for this journey is https://lambdasistemi.github.io/singular/docs/demo1-devnet/

You play two people, **Alice** and **Bob**, each in a tmux window of their own, and a third window holds the chain. You switch windows by clicking a word: `alice`, `bob` or `chain`. You will, step by step:

- create two wallets and a registry,
- book a key, fold it into the registry, read it back, change it and remove it,
- let a request go stale and reject it, and take another one back before its window closes.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on. Two steps wait a few minutes for the chain's own clock, and the page says when.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 15 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, and tmux, are being installed in the background. When the terminal says `Ready`, start.
