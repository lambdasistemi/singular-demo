# Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

```bash
# 14a. Alice books "carol". The receipt names the request, which she will need to take it back.
open-datum insert "${registry[@]}" --key carol --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14a-insert-carol.json
carol_request=$(jq -r .request receipts/14a-insert-carol.json)
carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{request, foldDeadline}' receipts/14a-insert-carol.json

# 14b. Reclaim right away: refused (exit status 10), the processing window is still open.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14b-reclaim-too-early.json
jq '{outcome, reason}' receipts/14b-reclaim-too-early.json

# 14c. Wait for the chain's clock (about two minutes), then reclaim with one command.
wait_for_slot "$carol_opens"
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14c-reclaim.json
jq '{outcome, request, returned}' receipts/14c-reclaim.json
```

`wait_for_slot` was defined in step 11. If this is a new terminal, define it again from there.
