# Step 2: join using the public token

Carol publishes only the registry token. Alice and Bob each make their own settings file, with their own journal. v0.17.0 has no read command. A creation receipt records what the command submitted and observed; it is not an independent read of current state. The private chain has no public explorer; the recorded preprod run links its public transaction IDs to an explorer.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
jq --arg blueprint "$blueprint" --arg token "$(cat ../registry.token)" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "alice-journal", "state-token": $token}' ../devnet.out > alice.json
jq . alice.json
```

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
jq --arg blueprint "$blueprint" --arg token "$(cat ../registry.token)" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "bob-journal", "state-token": $token}' ../devnet.out > bob.json
jq . bob.json
```
