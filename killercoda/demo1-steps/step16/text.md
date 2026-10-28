Bob prepares a registration for the key bob, signs its bundle with his own wallet, then submits it. Building alone sends nothing; exit status 19 means the bundle is waiting for signatures. Each part stays in Bob's directory.

**Build the registration.**

```bash
printf '{"answer":42}\n' > payload.json
jq 'del(.["state-token"])' bob.json > wallet.json
```{{exec}}

```bash
# Expected exit status: 19
open-datum insert --deposit 3000000 --key bob --payload payload.json --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle > receipts/12-insert-bob.json
```{{exec}}

**Sign with Bob's own vault.** The generic wallet settings omit the application-specific state token; the application command already put its transaction in the bundle.

```bash
singular wallet sign --config wallet.json --vault bob.vault --out witnesses/insert-bob bundles/insert-bob.bundle
```{{exec}}

**Submit the signed bundle** and wait for its confirmation.

```bash
singular submit --config wallet.json --witnesses witnesses/insert-bob --receipt receipts/12-insert-bob.submitted.json bundles/insert-bob.bundle
```{{exec}}

```bash
jq -er .expected.pending receipts/12-insert-bob.json > ../bob.pending
jq '{outcome, submissions}' receipts/12-insert-bob.submitted.json
```{{exec}}
