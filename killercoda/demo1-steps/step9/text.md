Alice needs her holding's transaction output to change its payload. The helper selects the one output from Bob's fold that carries the key's token, using the provider's transaction API. This supplies a reference for the next write; it is not a Singular key read and makes no independent claim about registry membership.

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

```bash
alice_holding=$(holding_in "$(cat ../registry.token)" "$(cat ../alice-fold.tx)") &&
printf '%s\n' "$alice_holding" > holding.ref &&
printf 'Holding for the next write: %s\n' "$alice_holding"
```{{exec}}
