The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back. The [documentation](https://lambdasistemi.github.io/singular/docs/singular-node/#reclaiming-your-pending-request).

**Alice books `carol`.** The receipt names the request, which she needs to take it back: `carol_request` keeps it, and `carol_opens` keeps the slot after which the retract window opens.

```bash
open-datum insert \
  --key carol --payload payload.json \
  --vault alice.vault \
  > receipts/14a-insert-carol.json
```{{exec}}

**Keep the request, and the slot after which its retract window opens:**

```bash
carol_request=$(jq -r .request receipts/14a-insert-carol.json); carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/14a-insert-carol.json
```{{exec}}

**Try to reclaim right away.** Refused (exit status 10, `client-refusal`): the retract window has not opened yet.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --vault alice.vault \
  > receipts/14b-reclaim-too-early.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason} | with_entries(select(.value != null))' receipts/14b-reclaim-too-early.json
```{{exec}}

**Wait for the chain's clock** to pass the end of the processing window. About three minutes.

```bash
wait_for_slot "$carol_opens"
```{{exec}}

**Reclaim**, with one command. Now the retract window is open: Alice takes her request back, and her deposit with it. Her vault signs and sends.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --vault alice.vault \
  > receipts/14c-reclaim.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, request, returned} | with_entries(select(.value != null))' receipts/14c-reclaim.json
```{{exec}}
