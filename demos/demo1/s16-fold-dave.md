# Step 16: Bob folds the final registration with external signing

Bob builds a fold of whatever is pending, which is the registration of dave, signs its bundle with his own wallet, then submits it. The receipt records the confirmed transaction and its outputs.

**Now Bob.**

```bash { window=bob }
bob
```

**Build the fold.** Exit status 19 means waiting for signatures; nothing has been sent.

```bash { window=bob status=19 }
open-datum fold --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle > receipts/16a-fold-dave.json
```

**Sign with Bob's own vault.**

```bash { window=bob }
singular wallet sign --config wallet.json --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle
```

**Submit and wait for confirmation.**

```bash { window=bob }
singular submit --config wallet.json --witnesses witnesses/fold-dave --receipt receipts/16a-fold-dave.submitted.json bundles/fold-dave.bundle
```

```bash { window=bob }
jq '{outcome, expected}' receipts/16a-fold-dave.json
jq '{outcome, submissions}' receipts/16a-fold-dave.submitted.json
```
