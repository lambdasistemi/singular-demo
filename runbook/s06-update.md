# Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change.

**The new payload**: the integer 43.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
```

**The update.** It asks for Alice's passphrase and takes effect at once.

```bash
open-datum update "${registry[@]}" --key alice --payload payload-new.json "${provider[@]}" "${alice[@]}" > receipts/06-update.json
jq '{outcome, payload}' receipts/06-update.json
```

**The root before and after is the same.** An update changes the key's data but not the registry's fingerprint: both lines show the same value.

```bash
echo "root before: $(jq -r .root receipts/05-inspect.json)"; echo "root after:  $(jq -r .root receipts/06-update.json)"
```
