# Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

`wait_for_slot` was defined in step 11. In a new terminal, define it again from there.

Alice books `carol` (her passphrase). The receipt names the request, which she needs to take it back:

```bash
# Book the key "carol". The receipt names the request (transaction#output), which Alice needs to take it back.
open-datum insert "${registry[@]}" --key carol --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/14a-insert-carol.json
# Keep the request, and the slot after which the retract window opens.
carol_request=$(jq -r .request receipts/14a-insert-carol.json); carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{request, foldDeadline}' receipts/14a-insert-carol.json
```

Reclaim right away: refused (exit status 10), because the processing window is still open:

```bash
# Try to take the request back at once. Refused (exit status 10): the retract window has not opened yet.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" > receipts/14b-reclaim-too-early.json
jq '{outcome, reason}' receipts/14b-reclaim-too-early.json
```

Wait for the chain's clock, about two minutes:

```bash
# Wait until the chain's clock passes the end of the processing window.
wait_for_slot "$carol_opens"
```

Reclaim, with one command (her passphrase):

```bash
# Now the retract window is open: Alice takes her request back, and her deposit with it. Her vault signs and sends.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" > receipts/14c-reclaim.json
jq '{outcome, request, returned}' receipts/14c-reclaim.json
```
