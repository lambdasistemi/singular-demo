Dave adds the key `dave`, with his address as the payload, folds his own booking, and checks that he controls the name. These are the steps Alice took.

```bash
sink-tools addr-json "$dave_addr" > payload.json
```{{exec}}

```bash
open-datum insert --key dave --payload payload.json --payload-schema detailed --vault dave.vault > insert.json
```{{exec}}

```bash
open-datum fold --vault dave.vault > fold.json
```{{exec}}

```bash
open-datum inspect --key dave > inspect.json
```{{exec}}

```bash
[ "$(jq -r .applicationOutput.controller inspect.json)" = "$(sink-tools addr-keyhash "$dave_addr")" ] && echo "Dave controls 'dave'" || echo "NOT Dave's"
```{{exec}}

Now he replies to Bob with his name.

```bash
jq -r .keyText inspect.json > ../messages/dave-to-bob.txt
cat ../messages/dave-to-bob.txt
```{{exec}}
