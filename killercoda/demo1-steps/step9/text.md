Alice reads her key back from the chain. `open-datum inspect` answers `live`: the holding carries her payload and her protected deposit. The read signs nothing and needs only the registry token and the chain's web API, from her settings file. Its `outputRef` is the holding she spends to change the payload.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
open-datum inspect --key alice --json > receipts/05-read-alice.json
jq '{answer, payload, deposit, holding: .outputRef}' receipts/05-read-alice.json
jq -er .outputRef receipts/05-read-alice.json > holding.ref
```{{exec}}
