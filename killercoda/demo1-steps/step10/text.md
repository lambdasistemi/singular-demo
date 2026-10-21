Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change.

**The new payload**: the integer 43.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
```{{exec}}

**The update.** It takes effect at once.

```bash
open-datum update \
  --key alice --payload payload-new.json \
  --vault alice.vault \
  > receipts/06-update.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, payload} | with_entries(select(.value != null))' receipts/06-update.json
```{{exec}}

**The payload changed, and the root did not.** The first two lines show the payload before and after: 42, then 43. The last two show the registry's root, which is the same on both lines. That is correct. The root is the registry's fingerprint of which keys exist and in what state, so it moves only when a fold settles an insertion or a removal. The payload is not part of it: it lives in the key's own output, which is what the update replaced.

```bash
echo "payload before: $(jq -c .applicationOutput.payload receipts/05-inspect.json)"; echo "payload after:  $(jq -c .payload receipts/06-update.json)"
echo "root before:    $(jq -r .root receipts/05-inspect.json)"; echo "root after:     $(jq -r .root receipts/06-update.json)"
```{{exec}}
