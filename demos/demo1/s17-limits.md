# Where this design stops

This tutorial is for people exploring a registry on a private chain. It shows registration, a direct payload update, permanent termination, reading a key back after each change, a requester reclaim and public cleanup after expiry. It does not establish mainnet readiness.

**The trie library's proofs are assumed sound.**

**Folding is open and optional.** A registration needs a fold before its processing deadline. A fold finds the pending requests on the chain and folds every one it can fit in one transaction; `--limit` caps how many, and repeated `--pending` names an exact batch instead. An unprocessed registration can be reclaimed by the refund address in its reclaim window, or cleaned up by anyone after that window ends. A termination has no reclaim path.

**Termination is permanent.** Its protected deposit goes to the treasury when termination is booked. The fold burns the active token and approval. The key cannot be registered again.

**Receipts and reads say different things.** A receipt reports what a command submitted and observed when it ran. A read reports the key's state when it runs, from the chain through the provider. A read the provider cannot answer exits 1 and says why.

**An interrupted send needs reconciliation.** Keep its receipt and journal. No step retries an uncertain submission automatically.

**Private-chain evidence and preprod evidence are separate.** The recorded preprod run uses released binaries and public explorer links. Local tests do not establish hosted CI, deployment, independent audit or acceptance.
