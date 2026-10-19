# Step 4: fold it (Bob signs outside the program)

A fold moves pending requests into the registry for good. Anyone may do it, and here Bob does, the external way: his command only names his address and a bundle file. It builds the transactions, writes them into that file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. It is not an error.

**Why Bob, and not Alice?** Nothing requires it. Anyone may fold, and the wallet that folds need not be the one that booked; the fold's receipt names the requests it settles. The demo has Bob fold Alice's booking for two reasons: it shows that a fold is open to every wallet, and it shows the second way of signing, Bob's, next to Alice's. Alice could just as well fold her own booking: `open-datum insert` takes a `--fold` switch that books and folds in one command with one wallet. Step 13 has Alice fold Bob's request.

Then Bob signs the bundle with his vault, and the signed bundle is sent; the send waits until the transactions have landed. Run the three pieces before the fold deadline of step 3.

**Build the fold into a bundle file.** Bob is named only by his public address; no key is used here.

- `--wallet-address`: who will pay and sign later
- `--bundle`: the file the finished, unsigned transactions are written to, in `bundles/`
- in the output, `settling` is what the fold will settle and `msLeft` the time left before the fold deadline

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle \
  > receipts/04-fold-insert.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/04-fold-insert.json
```

**Bob signs the bundle with his vault** (witnesses are signatures). His key is used inside the command and never leaves it. It asks for Bob's passphrase.

- `--out`: where the signatures are written, in `witnesses/`

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-insert bundles/fold-insert.bundle
```

**Send the signed bundle** and wait until the chain has accepted it.

- `--receipt`: where the proof of landing is written, in `receipts/`
- `slot` in the output is where on the chain it landed

```bash
singular submit \
  --witnesses witnesses/fold-insert --receipt receipts/04-fold-insert.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-insert.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json
```
