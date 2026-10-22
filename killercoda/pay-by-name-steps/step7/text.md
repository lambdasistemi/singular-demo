**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 1`.

```bash
alice
```{{exec}}

Alice reads Bob's message. First she checks that it names the registry she already uses.

```bash
cat ../messages/bob-to-alice.json
```{{exec}}

```bash
[ "$(jq -r .registry ../messages/bob-to-alice.json)" = "$(jq -r .registry singular.json)" ] && echo "the same registry" || echo "a different registry"
```{{exec}}

She has a name, so she replies at once. The reply is one line: her name, read back from the key.

```bash
jq -r .keyText inspect.json > ../messages/alice-to-bob.txt
cat ../messages/alice-to-bob.txt
```{{exec}}
