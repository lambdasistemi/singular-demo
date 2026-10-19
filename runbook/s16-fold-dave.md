# Step 16: fold "dave" (Bob signs outside the program), then read it

Bob folds `dave`, external signing as before: build (exit status 19), sign, send. Afterwards an independent read asks the chain for the key and finds it active. That is the last proof that the whole journey worked.

Build the bundle:

```bash
# Build Bob's fold of "dave" into a bundle (exit status 19, nothing sent). Same as steps 4 and 9.
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle > receipts/16a-fold-dave.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/16a-fold-dave.json
```

Bob signs (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle
```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-dave "${provider[@]}" --receipt receipts/16a-fold-dave.submitted.json bundles/fold-dave.bundle
```

Read `dave` back:

```bash
# The independent check: ask the chain for "dave". It should be active.
open-datum inspect "${registry[@]}" --key dave "${provider[@]}" > receipts/16b-inspect-dave.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, root}' receipts/16b-inspect-dave.json
```
