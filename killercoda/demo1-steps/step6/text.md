Carol publishes only the registry token. Alice and Bob each make their own settings file, with their own journal. v0.17.0 has no read command. A creation receipt records what the command submitted and observed; it is not an independent read of current state. The private chain has no public explorer; the recorded preprod run links its public transaction IDs to an explorer.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
jq --arg blueprint "$blueprint" --arg token "$(cat ../registry.token)" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "alice-journal", "state-token": $token}' ../devnet.out > alice.json
jq . alice.json
```{{exec}}

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

```bash
jq --arg blueprint "$blueprint" --arg token "$(cat ../registry.token)" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "bob-journal", "state-token": $token}' ../devnet.out > bob.json
jq . bob.json
```{{exec}}
