# Step 4: fold it (Bob signs outside the program)

A fold moves pending requests into the registry for good. Anyone may do it, and here Bob does, the external way: his command only names his address and a bundle file. It builds the transactions, writes them into that file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. It is not an error.

Then Bob signs the bundle with his vault, and the signed bundle is sent; the send waits until the transactions have landed. Run the three pieces before the fold deadline of step 3.

Build the fold into a bundle file:

```bash
# Fold the pending request. Bob is named only by his public address: no key is used here.
#   --wallet-address  who will pay and sign later
#   --bundle          the file the finished, unsigned transactions are written to (in bundles/)
# It exits with status 19 ("waiting for signatures") and sends nothing.
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle > receipts/04-fold-insert.json
# settling = what the fold will settle; msLeft = time left before the fold deadline
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/04-fold-insert.json
```

Bob signs the bundle with his vault (witnesses are signatures). It asks for Bob's passphrase:

```bash
# Bob signs the bundle with his vault; his key is used inside the command and never leaves it.
#   --out  where the signatures (witnesses) are written, in witnesses/
singular wallet sign --vault bob.vault --out witnesses/fold-insert bundles/fold-insert.bundle
```

Send the signed bundle and wait until it has landed:

```bash
# Send the bundle with Bob's signatures, and wait until the chain has accepted it.
#   --receipt  where the proof of landing is written, in receipts/
singular submit --witnesses witnesses/fold-insert "${provider[@]}" --receipt receipts/04-fold-insert.submitted.json bundles/fold-insert.bundle
# slot = where on the chain it landed
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json
```
