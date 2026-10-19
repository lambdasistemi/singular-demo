# Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change. The last line shows the root before and after.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
open-datum update "${registry[@]}" --key alice --payload payload-new.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/06-update.json
jq '{outcome, payload}' receipts/06-update.json
echo "root before: $(jq -r .root receipts/05-inspect.json)"; echo "root after:  $(jq -r .root receipts/06-update.json)"
```
