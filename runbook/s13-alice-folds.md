# Step 13: fold Bob's key (Alice, vault in one command)

Alice folds Bob's request. Here the fold is a single command, because it is her vault that signs and sends it, and it prints its receipt when it has landed. Run it before the fold deadline of step 12.

```bash
open-datum fold "${registry[@]}" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/13-fold-bob.json
jq '{outcome, settled: [.settled[] | {key, edge}], root}' receipts/13-fold-bob.json
```
