# Step 10: read the terminated key

Alice reads her key with `singular registry inspect`, which knows no application. It answers `terminal`: the key was registered and terminated, and can never be registered again. A key nobody registered answers `never-registered`. Both answers are read from the registry's state output on the chain.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
singular registry inspect --key alice --json > receipts/10-read-alice.json
jq '{answer, stateOutput, root}' receipts/10-read-alice.json
```

```bash { window=alice }
singular registry inspect --key nobody --json > receipts/10-read-nobody.json
jq '{answer, stateOutput, root}' receipts/10-read-nobody.json
```
