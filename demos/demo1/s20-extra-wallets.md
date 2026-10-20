# Extra: look at the wallets

The pages that follow are optional extras. Skip them in a short demo; the journey is complete without them.

A wallet holds outputs: coins at its address, each one named by the transaction that created it and an index. The devnet's web API lists them. Run this now to see what each wallet starts with, and again whenever you like, for instance after step 16, to see what the journey cost: deposits locked in requests, fees paid, tokens received.

`wallet_show ADDRESS` prints a short form: `total_ada` is what the wallet holds; each line of `utxos` is one output: the transaction that made it, its index, its ada and any tokens.

**Alice's wallet**, from her public address. No passphrase is needed to look. At the start she holds six outputs of 2000 ada.

```bash
wallet_show "$alice_addr"
```

**Bob's wallet**, the same way:

```bash
wallet_show "$bob_addr"
```

**The chain's own clock**, for reference. It is what the program uses to judge windows: the slot is the chain's unit of time.

```bash
curl -fsS "$(koios_url)/tip" | jq '.[0] | {abs_slot, block_no}'
```
