**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 3`.

```bash
bob
```{{exec}}

Bob has the two replies. A name is all he needs: he applies each one to the registry sink script he took from Carol's page, and the result is the address of that name's sink. Nobody has to tell him where Alice or Dave receive money.

```bash
alice_name=$(cat ../messages/alice-to-bob.txt)
dave_name=$(cat ../messages/dave-to-bob.txt)
sink-tools sink-address --registry-sink-script ../publish/registry.json --name "$alice_name" > sink-alice.json
sink-tools sink-address --registry-sink-script ../publish/registry.json --name "$dave_name" > sink-dave.json
cat sink-alice.json sink-dave.json
```{{exec}}

**Paying.** `sink-tools` does not hold keys. It writes the payment as a transaction nobody has signed yet, into a file called a bundle: 20 ada and 10 ada, as two outputs, to Alice's sink, and 15 ada to Dave's. Any ordinary payment to the sink's address works the same; this one is built that way so that Bob's vault can sign it.

```bash
sink_alice=$(jq -r .address sink-alice.json); sink_dave=$(jq -r .address sink-dave.json)
sink-tools pay --from "$bob_addr" --out "$sink_alice:20000000" --out "$sink_alice:10000000" --out "$sink_dave:15000000" --bundle fund.bundle
```{{exec}}

**Signing and sending.** `singular wallet sign` opens Bob's vault, signs the bundle, and writes the signature to a file (a witness). `singular submit` puts the signature with the transaction, sends it, and waits until it has landed.

```bash
singular wallet sign --vault bob.vault --out witnesses fund.bundle
```{{exec}}

```bash
singular submit --witnesses witnesses --receipt fund.submitted.json fund.bundle > fund.submit.out
jq -c '{outcome, transactions: [.submissions[] | {identity, how, confirmations}]}' fund.submitted.json
```{{exec}}

**The money is in the sinks.** Anyone can look: a sink is an address like any other.

```bash
wallet_show "$sink_alice"
wallet_show "$sink_dave"
```{{exec}}
