# Step 1: Carol creates the registry

Carol starts a registry for the group. Its token identifies it for everyone; creating it gives Carol no exclusive right to fold requests. Each actor signs in their own directory. The processing and reclaim windows are fixed when the registry is created.

**Now Carol.**

```bash { window=carol }
carol
```

```bash { window=carol }
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "carol-journal"}' ../devnet.out > carol.json
process_ms=${PROCESS_TIME_MS:-180000}; retract_ms=${RETRACT_TIME_MS:-60000}
open-datum create --process-time "$process_ms" --reclaim-time "$retract_ms" --booking-width 60000 --vault carol.vault > receipts/01-create.json
```

```bash { window=carol }
jq '{outcome, registry, stateToken, root, submissions}' receipts/01-create.json
jq -er .stateToken receipts/01-create.json > ../registry.token
```
