# Step 2: read the registry's page, and give its address to Bob

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. It needs no key and no wallet, because reading is free. The page is read from the chain's provider, so it is what the chain says and not a signed statement. The command needs nothing typed: Alice's file gives it the contracts, the registry and the chain. [What each part of the page means](https://lambdasistemi.github.io/singular/docs/registry-page/).

The page is printed as JSON, and `tee` keeps a copy:

```bash { window=alice }
singular registry describe | tee receipts/02-describe.json
```

**Giving the registry to Bob.** Bob is on another machine. Alice gives him one thing, the registry's address. With it, a chain connection and the contracts, he needs nothing else. She would send it in a message; here the file `registry.address` stands for the message.

```bash { window=alice }
jq -r .registry receipts/01-create.json > ../registry.address
cat ../registry.address
```

**Now Bob.**

```bash { window=bob }
bob
```

**Bob's settings** are his own: the same chain and contracts, a journal folder of his own, and no registry yet.

```bash { window=bob }
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "bob-journal"}' ../devnet.out > bob.json
jq . bob.json
```

**He writes the address into his file** as `registry`:

```bash { window=bob }
jq --arg address "$(cat ../registry.address)" '.registry = $address' bob.json > bob.new && mv bob.new bob.json
jq . bob.json
```

**Bob reads the registry's page**, with the same command. It names the registry by the address he was given:

```bash { window=bob }
singular registry describe | tee receipts/02-describe-bob.json
```
