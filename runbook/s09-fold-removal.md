# Step 9: fold the removal (Bob signs outside the program)

Bob folds the termination, the external way again: build (exit status 19), sign, send. When it lands, the key's token is burned and the deposit goes back to Alice. Run the three pieces before the fold deadline of step 8.

**Build the bundle**, as in step 4: nothing is signed or sent.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-terminate.bundle \
  > receipts/09-fold-terminate.json
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/09-fold-terminate.json
```

**Bob signs it** with his vault (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-terminate bundles/fold-terminate.bundle
```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/fold-terminate --receipt receipts/09-fold-terminate.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-terminate.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/09-fold-terminate.submitted.json
```

**If the first command was refused because the window ended.** The read-back shows it in `reason`: the request's processing deadline is before the moment the fold would be built. Nothing is lost. The termination is still pending and its deposit is locked. A removal cannot be taken back with a reclaim (the project's page says updates and deletions cannot be retracted), so the way out is the reject of step 11. Once both windows have passed, any wallet may reject; here it is Bob's, and it returns the deposit. After that, book the removal again (step 8) and go straight to this page.

```bash skip
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject-late.bundle \
  > receipts/09-reject.json
```

```bash skip
singular wallet sign --vault bob.vault --out witnesses/reject-late bundles/reject-late.bundle
```

```bash skip
singular submit --witnesses witnesses/reject-late \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/reject-late.bundle
```
