# Step 13: fold Bob's key (Alice, vault in one command)

Alice folds Bob's request. Here the fold is a single command, because it is her vault that signs and sends it (her passphrase), and it prints its receipt when it has landed. Run it before the fold deadline of step 12.

```bash
# Anyone may fold: here Alice does, with her vault, in one command (build, sign, send, wait).
open-datum fold "${registry[@]}" "${provider[@]}" "${alice[@]}" > receipts/13-fold-bob.json
# settled = the requests now part of the registry; root = the registry's new fingerprint
jq '{outcome, settled: [.settled[] | {key, edge}], root}' receipts/13-fold-bob.json
```
