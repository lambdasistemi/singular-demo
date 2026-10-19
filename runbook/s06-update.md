# Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change.

**The new payload**: the integer 43.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
```

**The update.** It asks for Alice's passphrase and takes effect at once.

```bash
open-datum update \
  --key alice --payload payload-new.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/06-update.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, payload} | with_entries(select(.value != null))' receipts/06-update.json
```

**The root before and after is the same.** An update changes the key's data but not the registry's fingerprint: both lines show the same value.

```bash
echo "root before: $(jq -r .root receipts/05-inspect.json)"; echo "root after:  $(jq -r .root receipts/06-update.json)"
```
