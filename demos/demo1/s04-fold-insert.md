# Step 4: fold it (Bob signs outside the program)

Run these three, one after the other, now. They build Bob's fold of the booking, sign it with his vault and send it; what each one is was explained on the previous page.

**Now Bob.**

```bash { window=bob }
bob
```

**Build the fold into a bundle file** (exit status 19, nothing sent). In the output, `settling` is what the fold will settle and `msLeft` the time left before the fold deadline.

```bash { window=bob status=19 }
open-datum fold \
  --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle \
  > receipts/04-fold-insert.json
```

**Read what it returned:**

```bash { window=bob }
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/04-fold-insert.json
```

**Bob signs the bundle:**

```bash { window=bob }
singular wallet sign --vault bob.vault --out witnesses/fold-insert bundles/fold-insert.bundle
```

**Send the signed bundle** and wait until it has landed. `slot` in the output is where on the chain it landed.

```bash { window=bob }
singular submit --witnesses witnesses/fold-insert --receipt receipts/04-fold-insert.submitted.json \
  bundles/fold-insert.bundle
```

```bash { window=bob }
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json
```

**If the first command was refused because the window ended.** The [documentation on recovery](https://lambdasistemi.github.io/singular/docs/cli-recovery/) covers it.

The refusal says so in `reason`. Nothing is lost: the booking is still pending and its deposit is locked, and a request nobody folds can be taken back or rejected. See where the chain is compared with the booking's deadline:

```bash { window=alice mode=show }
jq '{request, foldDeadline}' receipts/03-insert-alice.json
```

```bash { window=alice mode=show }
curl -fsS "$(koios_url)/tip" | jq '.[0] | {abs_slot}'
```

- While the chain's slot is **below** `foldDeadline.slot`, the fold is still possible: run the three commands again.
- Once it is **past** `foldDeadline.slot` and the retract window is still open, Alice takes her request back with a reclaim. Then book again (step 3) and fold at once:

```bash { window=alice mode=show }
singular registry reclaim \
  --request "$(jq -r .request receipts/03-insert-alice.json)" \
  --vault alice.vault \
  > receipts/04-reclaim.json
```

- If the retract window has ended too, the reclaim is refused, and the way out is a reject: any wallet may do it once both windows have passed, and it returns the deposit. Or start the scenario again: a fresh machine takes about a minute.
