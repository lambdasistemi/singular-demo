# Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file opened by a passphrase file. Alice and Bob each get one, and the key never leaves it. Then `devnet` starts a private test chain that funds those two addresses with 6 coins of 2000 ada each. Nothing here touches a public network.

The devnet prints one line of settings when it is up. The commands wait for it, so there is nothing to time by hand.

```bash
# A folder of your own for the vaults, receipts and the registry's saved state.
mkdir -p ~/singular-demo-run && cd ~/singular-demo-run
mkdir -p receipts bundles witnesses

# Two vaults. Each passphrase file is read by the command through file descriptor 3 (3< file).
umask 077
printf '%s\n' "alice passphrase" > alice.passphrase
printf '%s\n' "bob passphrase" > bob.passphrase
singular wallet create --vault alice.vault --network-magic 42 --passphrase-fd 3 3< alice.passphrase
singular wallet create --vault bob.vault --network-magic 42 --passphrase-fd 3 3< bob.passphrase

# Their public addresses, read back from the vaults.
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42 --passphrase-fd 3 3< alice.passphrase)
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42 --passphrase-fd 3 3< bob.passphrase)

# The private chain, started in the background. Its settings line goes to devnet.out.
devnet --fund-address "$alice_addr:6:2000000000" --fund-address "$bob_addr:6:2000000000" > devnet.out 2> devnet.err &
devnet_pid=$!

# Wait until the settings line has appeared, then show it.
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do sleep 1; done
jq . devnet.out
```
