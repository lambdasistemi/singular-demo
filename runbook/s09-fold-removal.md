# Step 9: fold the removal (Bob signs outside the program)

Bob folds the termination, the external way again: build (exit status 19), sign, send. When it lands, the key's token is burned and the deposit goes back to Alice. Run the three pieces before the fold deadline of step 8.

Build the bundle:

```bash
# Same as step 4: build the fold for Bob into a bundle file (exit status 19, nothing sent).
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-terminate.bundle > receipts/09-fold-terminate.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/09-fold-terminate.json
```

Bob signs it (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/fold-terminate bundles/fold-terminate.bundle
```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-terminate "${provider[@]}" --receipt receipts/09-fold-terminate.submitted.json bundles/fold-terminate.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/09-fold-terminate.submitted.json
```
