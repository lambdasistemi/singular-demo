What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending keeps its deposit locked, and other requests can still be folded meanwhile. Once its two windows (processing, then retract) are over, the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock. The [documentation](https://lambdasistemi.github.io/singular/docs/singular-node/#rejecting-expired-requests); the contract that settles the refund of a rejected request is [settlement.ak](https://github.com/lambdasistemi/singular/blob/v0.16.0/onchain/lib/registry/settlement.ak).

**Alice books `late`.** Nobody will fold it, so the request stays pending.

```bash
open-datum insert \
  --key late --payload payload.json \
  --vault alice.vault \
  > receipts/11a-insert-late.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/11a-insert-late.json
```{{exec}}

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

**Bob asks to reject it now**, naming only his address, no key. It is too early, so the program refuses: exit status 10, outcome `client-refusal`, nothing built. The refusal says when the retract window closes: `retractEndsSlot` is the slot where the window closes and `tipSlot` is where the chain is now.

```bash
singular registry reject \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11b-reject-too-early.json
jq '{outcome, reason, pending: [.pendingRequests[]? | {request, retractEndsSlot}], tipSlot} | with_entries(select(.value != null))' receipts/11b-reject-too-early.json
```{{exec}}

**Wait until the tip passes the end of the retract window**, named in the refusal. `wait_for_slot N` asks the chain for its latest slot every 2 seconds until it is past `N`, by the chain's clock, like the program does. About four minutes.

```bash
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"
```{{exec}}

**Both windows are over.** Bob asks again, the external way. This time the program builds the transaction: it returns the request's locked value to its owner, Alice. Exit status 19, nothing sent yet.

```bash
singular registry reject \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11d-reject.json
jq '{outcome, reason, rejected: [.expected.rejected[]? | {key, request}]} | with_entries(select(.value != null))' receipts/11d-reject.json
```{{exec}}

**Bob signs:**

```bash
singular wallet sign --vault bob.vault --out witnesses/reject bundles/reject.bundle
```{{exec}}

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/reject --receipt receipts/11d-reject.submitted.json \
  bundles/reject.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json
```{{exec}}
