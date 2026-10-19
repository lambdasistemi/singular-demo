# Finish: stop the devnet

The devnet was started in the background. This stops it and its node. The receipts stay in `receipts/`, the bundles in `bundles/`, the signatures in `witnesses/`.

```bash
# Stop the private chain started at the beginning.
kill "$devnet_pid"
```
