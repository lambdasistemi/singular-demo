# Alice changes her address

Alice wants her money to arrive at `alice2` from now on. Nobody else has to be told: the sink reads the address from the registry every time money moves.

**The change.** She updates the payload of `alice` to the address of her second wallet. Only the controller may, and it takes effect at once, with no fold.

```bash alice
sink-tools addr-json "$alice2_addr" > payload-new.json
```

```bash alice
open-datum update --key alice --payload payload-new.json --vault alice.vault > update.json
```

```bash alice
jq '{outcome}' update.json
open-datum inspect --key alice | jq -c '.applicationOutput.payload'
cat payload-new.json
```

**A move to the old address is refused.** `--to` names the address the money goes to instead of the registered one. The sink checks that what leaves it arrives at the registered address or returns to the sink, and the old address is neither. The program that builds the transaction runs the sink's script first and stops with the check that failed. `sink-conservation` is the one that says the money did not come back or reach the registered address.

```bash alice
sink-tools move --active-policy "$active" --name alice --from "$alice_addr" --lovelace 5000000 --to "$alice_addr" --bundle old.bundle
```

**A move to the new address goes through.**

```bash alice
sink-tools move --active-policy "$active" --name alice --from "$alice_addr" --lovelace 10000000 --bundle new.bundle
```

```bash alice
singular wallet sign --vault alice.vault --out witnesses-new new.bundle
```

```bash alice
singular submit --witnesses witnesses-new --receipt new.submitted.json new.bundle > new.submit.out
jq -c '{outcome, transactions: [.submissions[] | {identity, how, confirmations}]}' new.submitted.json
```

The 10 ada are at the address of `alice2`:

```bash alice
outputs_at "$alice2_addr" "$(jq -r '.submissions[0].identity' new.submitted.json)"
```
