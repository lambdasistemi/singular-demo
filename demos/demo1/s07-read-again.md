# Step 7: read the update receipt

The receipt identifies the new holding and the confirmed transaction. Reading a saved receipt does not query current registry state. Keep the new holding reference: the previous output has been spent.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
jq '{outcome, holding, submissions: [.submissions[] | {step, tx, case, observed}]}' receipts/06-update.json
```
