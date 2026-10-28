The booking receipt records the treasury donation. Bob's fold receipt records the pending request it settled and the resulting state output. These are transaction receipts, not an independent read of the key's current state. Do not attempt to re-register a terminated key.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
jq '{outcome, pending, treasuryDonation}' receipts/08-terminate.json
```{{exec}}
