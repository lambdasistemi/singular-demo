# Step 13: fold Bob's key (Alice, vault in one command)

Anyone may fold, and here Alice does. The fold is a single command, because it is her vault that signs and sends it: build, sign, send and wait, with her passphrase. It prints its receipt when it has landed. Run it before the fold deadline of step 12.

In the output, `settled` lists the requests now part of the registry and `root` is the registry's new fingerprint.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/13-fold-bob.json
```

**Read what it returned:**

```bash
jq '{outcome, settled: [.settled[] | {key, edge}], root}' receipts/13-fold-bob.json
```
