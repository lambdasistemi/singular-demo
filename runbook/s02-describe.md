# Step 2: read the registry's page

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. It needs no key and no wallet, because reading is free. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

The create receipt prints this exact command in its field `describeCommand`. It is written out here: the contracts, the registry's name, and the chain.

```bash
singular registry describe \
  --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  | tee receipts/02-describe.txt
```
