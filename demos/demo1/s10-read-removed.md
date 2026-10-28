# Step 10: review what termination recorded

The booking receipt records the treasury donation. Bob's fold receipt records the pending request it settled and the resulting state output. These are transaction receipts, not an independent read of the key's current state. Do not attempt to re-register a terminated key.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
jq '{outcome, pending, treasuryDonation}' receipts/08-terminate.json
```
