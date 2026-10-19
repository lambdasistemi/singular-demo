# Finish: stop the devnet

The devnet was started in the background at the beginning. This stops it and its node. The receipts stay in `receipts/`, the bundles in `bundles/`, the signatures in `witnesses/`.

```bash
kill "$devnet_pid"
```
