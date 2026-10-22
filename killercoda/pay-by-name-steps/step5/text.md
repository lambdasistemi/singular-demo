Alice adds the key `alice`. Its payload is her address, written as an address in Plutus data, in its detailed JSON form: an address is made of constructors and fields, which plain JSON cannot hold, so the commands that read this file say `--payload-schema detailed`. Money paid to `alice` goes to the address registered there.

```bash
sink-tools addr-json "$alice_addr" > payload.json
cat payload.json
```{{exec}}

**The booking.** Her vault signs it. It does not change the registry yet: it makes a request, which waits until somebody folds it into the registry. A fold is a command of its own, and anyone may run it. The request waits ten minutes for one.

```bash
open-datum insert --key alice --payload payload.json --payload-schema detailed --vault alice.vault > insert.json
```{{exec}}

```bash
jq '{outcome, request}' insert.json
```{{exec}}

**The fold.** Alice folds her own booking. After it the key is live.

```bash
open-datum fold --vault alice.vault > fold.json
```{{exec}}

```bash
jq '{outcome}' fold.json
```{{exec}}

**Does she control the name?** The controller of a key is the wallet that booked it, recorded as the hash of the wallet's key. Alice reads it back and compares it with the hash of her own address.

```bash
open-datum inspect --key alice > inspect.json
```{{exec}}

```bash
[ "$(jq -r .applicationOutput.controller inspect.json)" = "$(sink-tools addr-keyhash "$alice_addr")" ] && echo "Alice controls 'alice'" || echo "NOT Alice's"
```{{exec}}
