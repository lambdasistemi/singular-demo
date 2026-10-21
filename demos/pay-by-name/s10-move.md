# Alice and Dave move their money

Nobody has to be asked to release the money in a sink. **Anyone** may build a transaction that moves it, and the sink lets the transaction through if the money goes where the name says: to the address registered under it now, or back into the sink. Whoever builds the transaction also pays its small fee from their own wallet. Here it is Alice and Dave, each for their own sink. A stranger could do the same, and the money would go to Alice's address just the same.

**Alice moves 7 ada.** `sink-tools move` reads the registry for the output that holds the token of the name `alice`, and takes from its payload the address to pay. It builds the move: 7 ada to that address, the rest back to the sink. The transaction names that output as a reference input, so the sink can read it.

```bash alice
active=$(jq -r .registry.activeScript describe.json)
sink-tools move --active-policy "$active" --name alice --from "$alice_addr" --lovelace 7000000 --bundle move.bundle
```

Her vault signs, then the bundle is sent:

```bash alice
singular wallet sign --vault alice.vault --out witnesses-move move.bundle
```

```bash alice
singular submit --witnesses witnesses-move --receipt move.submitted.json move.bundle > move.submit.out
jq -c '{outcome, transactions: [.submissions[] | {identity, how, confirmations}]}' move.submitted.json
```

The 7 ada are at her address, an output of that transaction:

```bash alice
outputs_at "$alice_addr" "$(jq -r '.submissions[0].identity' move.submitted.json)"
```

**Dave moves 5 ada**, the same way, for the name `dave`:

```bash dave
active=$(jq -r .registry.activeScript describe.json)
sink-tools move --active-policy "$active" --name dave --from "$dave_addr" --lovelace 5000000 --bundle move.bundle
```

```bash dave
singular wallet sign --vault dave.vault --out witnesses-move move.bundle
```

```bash dave
singular submit --witnesses witnesses-move --receipt move.submitted.json move.bundle > move.submit.out
jq -c '{outcome, transactions: [.submissions[] | {identity, how, confirmations}]}' move.submitted.json
```

```bash dave
outputs_at "$dave_addr" "$(jq -r '.submissions[0].identity' move.submitted.json)"
```
