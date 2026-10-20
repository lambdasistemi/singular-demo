**Read the addresses and the chain's address.** The addresses were written to files when the wallets were made, and the chain's address is in the devnet's settings line. Read them into variables, in this window:

```bash
alice_addr=$(cat ../alice/alice.address); bob_addr=$(cat ../bob/bob.address); koios_url=$(jq -r .providerUrl ../devnet.out)
```{{exec}}

The pages that follow are optional extras. Skip them in a short demo; the journey is complete without them.

A wallet holds outputs: coins at its address, each one named by the transaction that created it and an index. The devnet's web API lists them. Run this now to see what each wallet starts with, and again whenever you like, for instance after step 16, to see what the journey cost: deposits locked in requests, fees paid, tokens received.

**A small helper** that asks the chain for the outputs at an address and prints a short form. `total_ada` is what the wallet holds; each line of `utxos` is one output: the transaction that made it, its index, its ada and any tokens.

```bash
wallet_show() { curl -fsS -X POST "$koios_url/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" | jq '{outputs: length, total_ada: ([.[] | (.value|tonumber)] | add / 1000000), utxos: [.[] | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000), tokens: [.asset_list[]? | .asset_name[0:8]]}]}'; }
```{{exec}}

**Alice's wallet**, from her public address. No passphrase is needed to look. At the start she holds six outputs of 2000 ada.

```bash
wallet_show "$alice_addr"
```{{exec}}

**Bob's wallet**, the same way:

```bash
wallet_show "$bob_addr"
```{{exec}}

**The chain's own clock**, for reference. It is what the program uses to judge windows: the slot is the chain's unit of time.

```bash
curl -fsS "$koios_url/tip" | jq '.[0] | {abs_slot, block_no}'
```{{exec}}
