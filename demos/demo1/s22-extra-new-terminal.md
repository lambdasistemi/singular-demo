# Extra: a new terminal in the middle

The values below live only in the terminal where they were pasted: the two addresses and `koios_url`. The chain, the contracts and the registry's name are in `singular.json`, so they survive a new terminal. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds the rest from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

- `cd ~/singular-demo-run`: back to the demo folder, where `singular.json` is
- the two `singular wallet address` lines read the public addresses from the vaults; each asks for its passphrase once
- `koios_url` is the web API's address, read from the devnet's line

```bash skip
cd ~/singular-demo-run
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
```

**Bob's, the same way:**

```bash skip
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
```

**Then:**

```bash skip
koios_url=$(jq -r .providerUrl devnet.out)
```

Steps 11 and 14 also use the `wait_for_slot` helper; paste its block from step 11 if it is missing.
