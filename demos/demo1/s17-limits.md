# Where this design stops

This tutorial is for people exploring a registry on a private chain. It shows registration, a direct payload update, permanent termination, a requester reclaim and public cleanup after expiry. It does not establish mainnet readiness.

**The trie library's proofs are assumed sound.**

**Folding is open and optional.** A registration needs a fold before its processing deadline. An unprocessed registration can be reclaimed by the refund address in its reclaim window, or cleaned up by anyone after that window ends. A termination has no reclaim path.

**Termination is permanent.** Its protected deposit goes to the treasury when termination is booked. The fold burns the active token and approval. The key cannot be registered again.

**Receipts have a limited meaning.** They report what a command submitted and observed through its provider. Reading one later is not an independent read of current state. v0.17.0 has no key read command. The holding helper selects a UTxO reference for a subsequent write through that same provider.

**An interrupted send needs reconciliation.** Keep its receipt and journal. No step retries an uncertain submission automatically.

**Private-chain evidence and preprod evidence are separate.** The recorded preprod run uses released binaries and public explorer links. Local tests do not establish hosted CI, deployment, independent audit or acceptance.
