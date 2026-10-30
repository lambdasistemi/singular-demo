Alice folds with her own wallet whatever is pending, which is Bob's registration. The fold is open to everyone and does not need Bob's key, payload file or journal, nor the reference of his booking.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
open-datum fold --vault alice.vault > receipts/13-fold-bob.json
```{{exec}}

```bash
jq '{outcome, folded, skipped, left, root}' receipts/13-fold-bob.json
```{{exec}}
