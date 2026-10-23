# Finish: stop the devnet

The devnet was started in the background at the beginning. In an unattended run it stops with the tutorial's own shells; the receipts stay in `receipts/`, the bundles in `bundles/`, the signatures in `witnesses/`. Whoever keeps the windows (interactive play) stops it with:

```bash { window=chain mode=show }
kill "$devnet_pid"
```
