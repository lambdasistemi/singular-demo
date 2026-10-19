# Step 2: read the registry's page

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. The create receipt contains the exact command, in its field `describeCommand`, and this runs it as printed. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

```bash
# Run the "singular registry describe" command that the create receipt printed. It needs no key: reading is free.
eval "$(jq -r .describeCommand receipts/01b-create.json)"
```
