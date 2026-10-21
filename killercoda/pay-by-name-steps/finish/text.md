That was the whole story: a registry made and published, two names put in it, a payment to both names, the money moved to the addresses registered under them, and one address changed. Everything ran on a private test chain.

**Stop the chain.**

Go to the chain's window: click `chain`, or press `Ctrl-b 4`.

```bash
chain
```{{exec}}

The chain is job 1 of its window. Stop it:

```bash
kill %1
```{{exec}}

The window keeps its shell.

The chain's messages are in `~/singular-demo-run/devnet.log`. Each person's files are in their own folder under `~/singular-demo-run`; Carol's page is `publish/registry.json` and the messages are in `messages`.
