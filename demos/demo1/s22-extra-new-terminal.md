# Extra: a new terminal in the middle

The values below live only in the terminal where they were pasted: the two addresses and the passphrase variable. The chain, the contracts and the registry's name are in `singular.json`, so they survive a new terminal. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds the rest from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

- `cd ~/singular-demo-run`: back to the demo folder, where `singular.json` is
- `export SINGULAR_PASSPHRASE=demo`: the vaults' passphrase, set again for this terminal
- the two `singular wallet address` lines read the public addresses from the vaults

```bash skip
cd ~/singular-demo-run
export SINGULAR_PASSPHRASE=demo
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
```

**Bob's, the same way:**

```bash skip
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
```

**Then the helpers** `koios_url`, `wait_for_slot` and `wallet_show`, which the demo's windows load by themselves:

```bash skip
PLAY_RUN=$PWD; . helpers.sh
```
