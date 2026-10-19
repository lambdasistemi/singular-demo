# Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

```bash
# 11a. Alice books "late". Nobody will fold it.
open-datum insert "${registry[@]}" --key late --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/11a-insert-late.json
jq '{request, foldDeadline}' receipts/11a-insert-late.json

# 11b. Bob asks to reject it now. Refused (exit status 10) and nothing is built: it is still inside its windows.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11b-reject-too-early.json
jq '{outcome, pending: [.pendingRequests[] | {request, retractEndsSlot}], tipSlot}' receipts/11b-reject-too-early.json

# 11c. Wait for the chain's own clock: the tip must pass the end of the retract window (about three minutes).
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"
```

Both windows are over. Bob asks again, the external way, and this time the program builds the transaction: it returns the request's locked value to its owner, Alice. Build (exit status 19), sign, send.

```bash
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11d-reject.json
jq '{outcome, rejected: [.expected.rejected[] | {key, request}]}' receipts/11d-reject.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/reject bundles/reject.bundle 3< bob.passphrase
singular submit --witnesses witnesses/reject "${provider[@]}" --receipt receipts/11d-reject.submitted.json bundles/reject.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json
```
