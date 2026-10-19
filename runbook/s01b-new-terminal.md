# If you open a new terminal in the middle

The shorthands (`provider`, `alice`, `registry`, the two addresses) live only in the terminal where they were pasted. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds them from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

```bash skip
# Back to the demo folder.
cd ~/singular-demo-run
# Alice's and Bob's public addresses, read from their vaults (each asks for its passphrase once).
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
# The chain's settings and the shorthands, as in step 1.
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)
alice=(--vault alice.vault)
# The registry's name, from the create receipt.
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")
```

Steps 11 and 14 also use the `wait_for_slot` helper; paste its block from step 11 if it is missing.
