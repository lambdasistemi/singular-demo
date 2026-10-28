Carol starts a registry for the group. Its token identifies it for everyone; creating it gives Carol no exclusive right to fold requests. Each actor signs in their own directory. The processing and reclaim windows are fixed when the registry is created.

**Now Carol.** Go to Carol's window: click `carol`, or press `Ctrl-b 3`.

```bash
carol
```{{exec}}

```bash
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "carol-journal"}' ../devnet.out > carol.json
process_ms=${PROCESS_TIME_MS:-180000}; retract_ms=${RETRACT_TIME_MS:-60000}
open-datum create --process-time "$process_ms" --reclaim-time "$retract_ms" --booking-width 60000 --vault carol.vault > receipts/01-create.json
```{{exec}}

```bash
jq '{outcome, registry, stateToken, root, submissions}' receipts/01-create.json
jq -er .stateToken receipts/01-create.json > ../registry.token
```{{exec}}
