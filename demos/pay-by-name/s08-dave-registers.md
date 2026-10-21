# Dave registers his name and replies

Dave adds the key `dave`, with his address as the payload, folds his own booking, and checks that he controls the name. These are the steps Alice took.

```bash dave
sink-tools addr-json "$dave_addr" > payload.json
```

```bash dave
open-datum insert --key dave --payload payload.json --vault dave.vault > insert.json
```

```bash dave
open-datum fold --vault dave.vault > fold.json
```

```bash dave
open-datum inspect --key dave > inspect.json
```

```bash dave
[ "$(jq -r .applicationOutput.controller inspect.json)" = "$(sink-tools addr-keyhash "$dave_addr")" ] && echo "Dave controls 'dave'" || echo "NOT Dave's"
```

Now he replies to Bob with his name.

```bash dave
jq -r .keyText inspect.json > ../messages/dave-to-bob.txt
cat ../messages/dave-to-bob.txt
```
