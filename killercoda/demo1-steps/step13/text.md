Anyone can fold the public termination request. Bob first reads the key: `open-datum inspect` answers `pending-termination`, at the request Alice booked. Then he folds whatever is pending, as on step 4: the fold finds the termination, burns its approval and active token, and Bob receives the request's value after his fee. Alice's protected deposit has already gone to the treasury.

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

```bash
open-datum inspect --key alice --json > receipts/09-read-alice.json
jq '{answer, request: .outputRef}' receipts/09-read-alice.json
```{{exec}}

```bash
open-datum fold --vault bob.vault > receipts/09-fold-terminate.json
```{{exec}}

```bash
jq '{outcome, folded, skipped, left, root, stateOutput}' receipts/09-fold-terminate.json
```{{exec}}
