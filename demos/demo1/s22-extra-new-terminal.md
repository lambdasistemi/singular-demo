# Extra: a new terminal in the middle

The values below live only in the terminal where they were pasted: the two addresses, the passphrase variable and the two words that choose a settings file. The chain, the contracts and the registry are in the files `alice.json` and `bob.json`, so they survive a new terminal. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds the rest from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

- `cd ~/singular-demo-run`: back to the demo folder, where the settings files are
- `export SINGULAR_PASSPHRASE=demo`: the vaults' passphrase, set again for this terminal
- the two words `alice` and `bob`, as in the setup; after `alice` the commands read Alice's file, after `bob` Bob's
- the `singular wallet address` line reads the public address from the vault

```bash skip
cd ~/singular-demo-run
export SINGULAR_PASSPHRASE=demo
alice() { export SINGULAR_CONFIG="$PWD/alice.json"; }
bob() { export SINGULAR_CONFIG="$PWD/bob.json"; }
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
