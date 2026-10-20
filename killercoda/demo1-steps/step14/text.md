**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

The key `alice` is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
open-datum inspect \
  --key alice \
  > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json
```{{exec}}
