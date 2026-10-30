# Step 9: Bob folds the termination

Anyone can fold the public termination request. Bob first reads the key: `open-datum inspect` answers `pending-termination`, at the request Alice booked. Then he folds whatever is pending, as on step 4: the fold finds the termination, burns its approval and active token, and Bob receives the request's value after his fee. Alice's protected deposit has already gone to the treasury.

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
open-datum inspect --key alice --json > receipts/09-read-alice.json
jq '{answer, request: .outputRef}' receipts/09-read-alice.json
```

```bash { window=bob }
open-datum fold --vault bob.vault > receipts/09-fold-terminate.json
```

```bash { window=bob }
jq '{outcome, folded, skipped, left, root, stateOutput}' receipts/09-fold-terminate.json
```
