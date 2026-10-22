# Alice replies

Alice reads Bob's message. First she checks that it names the registry she already uses.

```bash alice
cat ../messages/bob-to-alice.json
```

```bash alice
[ "$(jq -r .registry ../messages/bob-to-alice.json)" = "$(jq -r .registry singular.json)" ] && echo "the same registry" || echo "a different registry"
```

She has a name, so she replies at once. The reply is one line: her name, read back from the key.

```bash alice
jq -r .keyText inspect.json > ../messages/alice-to-bob.txt
cat ../messages/alice-to-bob.txt
```
