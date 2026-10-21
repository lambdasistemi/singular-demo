The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. It needs no key and no wallet, because reading is free. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

The page is printed as JSON, and `tee` keeps a copy. The command needs nothing typed: `singular.json` gives it the contracts, the registry's name and the chain. The create receipt prints the same command in its field `describeCommand`, written out in full. [What each part of the page means](https://lambdasistemi.github.io/singular/docs/registry-page/).

```bash
singular registry describe | tee receipts/02-describe.json
```{{exec}}
