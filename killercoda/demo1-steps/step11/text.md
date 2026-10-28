The receipt identifies the new holding and the confirmed transaction. Reading a saved receipt does not query current registry state. Keep the new holding reference: the previous output has been spent.

```bash
jq '{outcome, holding, submissions: [.submissions[] | {step, tx, case, observed}]}' receipts/06-update.json
```{{exec}}
