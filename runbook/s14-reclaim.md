# Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

`wait_for_slot` was defined in step 11. In a new terminal, define it again from there.

**Alice books `carol`** (her passphrase). The receipt names the request, which she needs to take it back: `carol_request` keeps it, and `carol_opens` keeps the slot after which the retract window opens.

```bash
open-datum insert \
  --key carol --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14a-insert-carol.json
carol_request=$(jq -r .request receipts/14a-insert-carol.json); carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{request, foldDeadline}' receipts/14a-insert-carol.json
```

**Try to reclaim right away.** Refused (exit status 10, `client-refusal`): the retract window has not opened yet.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14b-reclaim-too-early.json
jq '{outcome, reason}' receipts/14b-reclaim-too-early.json
```

**Wait for the chain's clock** to pass the end of the processing window. About two minutes.

```bash
wait_for_slot "$carol_opens"
```

**Reclaim**, with one command (her passphrase). Now the retract window is open: Alice takes her request back, and her deposit with it. Her vault signs and sends.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14c-reclaim.json
jq '{outcome, request, returned}' receipts/14c-reclaim.json
```
