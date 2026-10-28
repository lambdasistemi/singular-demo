Bob needs the public token, the pending reference, chain data and his own wallet. He receives no file from Alice's wallet or journal. The fold creates Alice's holding with its payload and deposit.

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

```bash
open-datum fold --pending "$(cat ../alice.pending)" --vault bob.vault > receipts/04-fold-insert.json
```{{exec}}

```bash
jq '{outcome, folded, root, stateOutput, submissions}' receipts/04-fold-insert.json
jq -er '.stateOutput | split("#")[0]' receipts/04-fold-insert.json > ../alice-fold.tx
```{{exec}}
