Carol, Alice and Bob use two programs to run a registry on a private Cardano chain. Each actor keeps their own wallet and journal.

**singular** provides wallet creation, wallet signing and transaction submission. Its generic registry creator takes an application policy; this demo uses the application-aware `open-datum create` with its processing and reclaim windows.

**open-datum** books a registration with `insert`, folds a named request with `fold`, directly updates a holding with `update`, and books its permanent termination with `terminate`. A pending registration can be taken back by its requester with `reclaim`, or cleaned up by anyone after expiry with `cleanup`.

A registration becomes a holding when it is folded. Its controller may change the payload directly. Termination donates the protected deposit to the treasury; its later fold burns the active token and approval. A terminated key cannot be registered again.

Anyone can read a key back from the chain, with no wallet: `open-datum inspect` shows a live holding with its payload and deposit, or a pending termination; `singular registry inspect` answers active, terminal or never registered and names the application. Both exit with status 0 for an answer, 1 when the chain cannot be read and 2 for a refusal. The steps read the key after each change.

The trie library's proofs are assumed sound.
