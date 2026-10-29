Alice reads her key with `singular registry inspect`, which knows no application. It answers `terminal`: the key was registered and terminated, and can never be registered again. A key nobody registered answers `never-registered`. Both answers are read from the registry's state output on the chain.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
singular registry inspect --key alice --json > receipts/10-read-alice.json
jq '{answer, stateOutput, root}' receipts/10-read-alice.json
```{{exec}}

```bash
singular registry inspect --key nobody --json > receipts/10-read-nobody.json
jq '{answer, stateOutput, root}' receipts/10-read-nobody.json
```{{exec}}
