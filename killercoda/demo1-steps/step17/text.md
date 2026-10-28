Alice folds Bob's named registration with her own wallet. The fold is open to everyone and does not need Bob's key, payload file or journal.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
open-datum fold --pending "$(cat ../bob.pending)" --vault alice.vault > receipts/13-fold-bob.json
```{{exec}}

```bash
jq '{outcome, folded, root, submissions}' receipts/13-fold-bob.json
```{{exec}}
