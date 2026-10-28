Bob builds a fold for the named registration, signs its bundle with his own wallet, then submits it. The receipt records the confirmed transaction and its outputs. v0.17.0 supplies no key read command; this is not an independent read of current registry state.

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

**Build the fold.** Exit status 19 means waiting for signatures; nothing has been sent.

```bash
# Expected exit status: 19
open-datum fold --pending "$(cat ../dave.pending)" --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle > receipts/16a-fold-dave.json
```{{exec}}

**Sign with Bob's own vault.**

```bash
singular wallet sign --config wallet.json --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle
```{{exec}}

**Submit and wait for confirmation.**

```bash
singular submit --config wallet.json --witnesses witnesses/fold-dave --receipt receipts/16a-fold-dave.submitted.json bundles/fold-dave.bundle
```{{exec}}

```bash
jq '{outcome, expected}' receipts/16a-fold-dave.json
jq '{outcome, submissions}' receipts/16a-fold-dave.submitted.json
```{{exec}}
