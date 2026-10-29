That was the whole of Demo 1: a key booked, folded, changed and removed, and read back after each change; an expired registration cleaned up after its two windows; a request taken back inside its window. Everything ran on a private test chain, with Carol, Alice and Bob each in their own window.

**Stop the chain.**

Go to the chain's window: click `chain`, or press `Ctrl-b 2`.

```bash
chain
```{{exec}}

The chain is job 1 of its window. Stop it:

```bash
kill %1
```{{exec}}

The window keeps its shell.

The chain's messages are in `~/singular-demo-run/devnet.log`. Alice's receipts are in `~/singular-demo-run/alice/receipts`; Bob's receipts, the transactions he built (`bundles/`) and his signatures (`witnesses/`) are in `~/singular-demo-run/bob`.
