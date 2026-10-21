# Alice registers her name

Alice adds the key `alice`. Its payload is her address, written as an address in Plutus data. Whoever pays `alice` will be sending money to the address that is registered there.

```bash alice
sink-tools addr-json "$alice_addr" > payload.json
cat payload.json
```

**The booking.** Her vault signs it. It does not change the registry yet: it makes a request, which waits until somebody folds it into the registry. A fold is a command of its own, and anyone may run it. The request waits ten minutes for one.

```bash alice
open-datum insert --key alice --payload payload.json --vault alice.vault > insert.json
```

```bash alice
jq '{outcome, request}' insert.json
```

**The fold.** Alice folds her own booking. After it the key is live.

```bash alice
open-datum fold --vault alice.vault > fold.json
```

```bash alice
jq '{outcome}' fold.json
```

**Does she control the name?** The controller of a key is the wallet that booked it, recorded as the hash of the wallet's key. Alice reads it back and compares it with the hash of her own address.

```bash alice
open-datum inspect --key alice > inspect.json
```

```bash alice
[ "$(jq -r .applicationOutput.controller inspect.json)" = "$(sink-tools addr-keyhash "$alice_addr")" ] && echo "Alice controls 'alice'" || echo "NOT Alice's"
```
