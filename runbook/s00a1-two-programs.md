# Before you start: two programs, one registry

Two command-line programs are used in this demo, `singular` and `open-datum`. Here is what each is for, so every command later has a reason.

**Singular is a registry of keys on Cardano.** A key exists at most once. A request to add or remove a key is first booked and waits; it becomes part of the registry when someone folds it, and the registry has rules for the waiting: a request that nobody folds can be rejected after its windows, and its owner can take it back inside the second window. Singular does not decide what a key means.

**An application gives the keys their meaning.** It decides what a key holds, who may change it, and what happens to the deposit locked with it. Applications plug into the registry and bring their own rules.

**`open-datum` is the application used here.** In it a key holds a piece of data, the payload, that only the key's controller may replace. The controller's deposit stays locked while the key exists and is released when the key is removed. `open-datum` is built on the registry: its commands create a registry tied to this application, and book, change, remove and read the keys.

Which program a command belongs to follows one rule:

- When the command depends on **what a key holds**, it is an `open-datum` command: `create`, `insert`, `update`, `terminate`, `fold` and `inspect`. It knows how the application lays out its data.
- When it does **not** depend on that, it is a `singular` command: making a wallet and reading its address (`singular wallet`), signing a prepared transaction and sending it (`singular wallet sign`, `singular submit`), describing the registry (`singular registry describe`), and the two exits for a stuck request, `singular registry reject` and `singular registry reclaim`.

`create` and `fold` exist in both programs. `singular registry create` takes the application to use as an option; `open-datum create` already knows its own. The demo uses the `open-datum` versions, which build the application's outputs.

The relation in one line: **`singular` runs the registry, `open-datum` is the application that fills it.**

Every write has the same shape: a command books or builds a transaction, a wallet signs it, and it is sent.

The code is in the project's repository: the contracts at https://github.com/lambdasistemi/singular/tree/v0.13.0/onchain, the programs at https://github.com/lambdasistemi/singular/tree/v0.13.0/offchain and https://github.com/lambdasistemi/singular/tree/v0.13.0/applications/open-datum. Every command and setting is described at https://lambdasistemi.github.io/singular/docs/singular-node/
