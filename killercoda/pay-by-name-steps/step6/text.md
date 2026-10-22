**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 3`.

```bash
bob
```{{exec}}

Bob owes Alice and Dave money and does not know where to send it. He knows Carol's registry, and he checks it the same way Alice did, because from now on he trusts it with his payments.

```bash
settings "$(jq -r .registry ../publish/registry.json)"
```{{exec}}

```bash
singular registry describe --blueprint "$blueprint" > describe.json
```{{exec}}

```bash
sink-tools check-registry describe.json --published ../publish/registry.json
```{{exec}}

**Two messages.** He asks each of them the same question. The files in the folder `messages` stand for the messages the three would send each other; each one names the registry by its address.

```bash
registry=$(jq -r .registry singular.json)
for who in alice dave; do jq -n --arg to "$who" --arg r "$registry" '{"from": "bob", "to": $to, "registry": $r, "message": "Do you have a name on this registry? Tell me your name and I will pay you there."}' > "../messages/bob-to-$who.json"; done
cat ../messages/bob-to-alice.json
```{{exec}}
