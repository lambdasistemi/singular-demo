# If you open a new terminal in the middle

The values below live only in the terminal where they were pasted: the two addresses, the chain's settings and the registry's name. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds them from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

- `cd ~/singular-demo-run`: back to the demo folder
- the two `singular wallet address` lines read the public addresses from the vaults; each asks for its passphrase once
- `koios_url` and `time_dir` are the two values of step 1
- `token` is the registry's name, read from the create receipt

```bash skip
cd ~/singular-demo-run
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
token=$(jq -r .stateToken receipts/01b-create.json)
```

Steps 11 and 14 also use the `wait_for_slot` helper; paste its block from step 11 if it is missing.
