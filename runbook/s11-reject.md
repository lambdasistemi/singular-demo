# Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

**Alice books `late`** (her passphrase). Nobody will fold it, so the request stays pending.

```bash
open-datum insert \
  --key late --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/11a-insert-late.json
jq '{request, foldDeadline}' receipts/11a-insert-late.json
```

**Bob asks to reject it now**, naming only his address, no key. It is too early, so the program refuses: exit status 10, outcome `client-refusal`, nothing built. The refusal says when the retract window closes: `retractEndsSlot` is the slot where the window closes and `tipSlot` is where the chain is now.

```bash
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11b-reject-too-early.json
jq '{outcome, pending: [.pendingRequests[] | {request, retractEndsSlot}], tipSlot}' receipts/11b-reject-too-early.json
```

**A small helper that waits for the chain's own clock.** `wait_for_slot N` asks the chain for its latest slot every 2 seconds until it is past `N`. It uses the chain's clock, like the program does. It is defined once here and used again in step 14.

```bash
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }
```

**Wait until the tip passes the end of the retract window**, named in the refusal. About three minutes.

```bash
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"
```

**Both windows are over.** Bob asks again, the external way. This time the program builds the transaction: it returns the request's locked value to its owner, Alice. Exit status 19, nothing sent yet.

```bash
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11d-reject.json
jq '{outcome, rejected: [.expected.rejected[] | {key, request}]}' receipts/11d-reject.json
```

**Bob signs** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/reject bundles/reject.bundle
```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/reject --receipt receipts/11d-reject.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/reject.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json
```
