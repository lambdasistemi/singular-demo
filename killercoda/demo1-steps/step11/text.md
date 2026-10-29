Alice reads the key again. It is still `live`, with the new payload and the same deposit, in the holding the update created. The previous holding has been spent.

```bash
open-datum inspect --key alice --json > receipts/07-read-alice.json
jq '{answer, payload, deposit, holding: .outputRef}' receipts/07-read-alice.json
```{{exec}}
