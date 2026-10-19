# Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

Alice books `late` (her passphrase). Nobody will fold it:

```bash
# Book the key "late". Nobody will fold it, so the request stays pending.
open-datum insert "${registry[@]}" --key late --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/11a-insert-late.json
jq '{request, foldDeadline}' receipts/11a-insert-late.json
```

Bob asks to reject it now. It is refused (exit status 10) and nothing is built, because the request is still inside its windows:

```bash
# Ask to reject the stuck request, as Bob (only his address, no key). Too early: the program refuses
# (exit status 10, "client-refusal"), builds nothing, and says when the retract window closes.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11b-reject-too-early.json
# retractEndsSlot = the slot the window closes at; tipSlot = where the chain is now
jq '{outcome, pending: [.pendingRequests[] | {request, retractEndsSlot}], tipSlot}' receipts/11b-reject-too-early.json
```

A small helper that waits for the chain's own clock to pass a slot (shown once, used here and in step 14):

```bash
# wait_for_slot N: ask the chain for its latest slot every 2 seconds until it is past N.
# It uses the chain's clock, not this computer's, like the program does.
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }
```

Wait until the tip passes the end of the retract window, about three minutes:

```bash
# Wait for the end of the retract window named in the refusal.
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"
```

Both windows are over. Bob asks again, the external way, and this time the program builds the transaction: it returns the request's locked value to its owner, Alice. Build (exit status 19):

```bash
# The same reject command as before. Now it builds the transaction: the deposit goes back to Alice.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11d-reject.json
jq '{outcome, rejected: [.expected.rejected[] | {key, request}]}' receipts/11d-reject.json
```

Bob signs (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/reject bundles/reject.bundle
```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/reject "${provider[@]}" --receipt receipts/11d-reject.submitted.json bundles/reject.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json
```
