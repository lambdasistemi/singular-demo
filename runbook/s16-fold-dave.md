# Step 16: fold "dave" (Bob signs outside the program), then read it

Bob folds `dave`, external signing as before: build (exit status 19), sign, send. Afterwards an independent read asks the chain for the key and finds it active. That is the last proof that the whole journey worked.

**Build the bundle**, as in steps 4 and 9: nothing is sent yet.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle \
  > receipts/16a-fold-dave.json
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/16a-fold-dave.json
```

**Bob signs** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle
```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/fold-dave --receipt receipts/16a-fold-dave.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-dave.bundle
```

**Read `dave` back**, the independent check. It should be active.

```bash
open-datum inspect \
  --key dave \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/16b-inspect-dave.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, root}' receipts/16b-inspect-dave.json
```

If the first command is refused because the window ended, the recovery is at the end of step 4 for a booking of a key (Alice reclaims while the retract window is open) and at the end of step 9 for the reject.
