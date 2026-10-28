Carol, Alice and Bob use two programs to run a registry on a private Cardano chain. Each actor keeps their own wallet and journal.

**singular** provides wallet creation, wallet signing and transaction submission. Its generic registry creator takes an application policy; this demo uses the application-aware `open-datum create` with its processing and reclaim windows.

**open-datum** books a registration with `insert`, folds a named request with `fold`, directly updates a holding with `update`, and books its permanent termination with `terminate`. A pending registration can be taken back by its requester with `reclaim`, or cleaned up by anyone after expiry with `cleanup`.

A registration becomes a holding when it is folded. Its controller may change the payload directly. Termination donates the protected deposit to the treasury; its later fold burns the active token and approval. A terminated key cannot be registered again.

v0.17.0 has no key read command. Saved receipts and the recorded preprod run's explorer links show transactions; they do not supply an independent read of current state.

The trie library's proofs are assumed sound.
