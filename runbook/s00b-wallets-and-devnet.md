# Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file opened by a passphrase that is typed when the command asks for it, and the key never leaves the vault. Alice and Bob each get one. Nothing here touches a public network.

Passphrases are not shown while typed. Use `alice` for Alice and `bob` for Bob, or anything else; the same one is asked again at every command that signs with that vault.

A folder of your own for the vaults, receipts and the registry's saved state:

```bash
# Make a working folder and go into it. Everything this demo writes stays here.
mkdir -p ~/singular-demo-run && cd ~/singular-demo-run
# receipts/   what each command printed, one JSON file per command, kept to read afterwards
# bundles/    transactions a command has built but not signed (written by --bundle)
# witnesses/  the signatures Bob makes for a bundle (written by "wallet sign")
mkdir -p receipts bundles witnesses
```

Alice's vault. It asks for a new passphrase twice and prints her address:

```bash
# Create a wallet: a vault file, alice.vault, holding an encrypted key.
#   --vault          the file to create
#   --network-magic  42 is the number of this private test chain (preprod is 1, mainnet 764824073)
# It prints her address; it also asks for a new passphrase, twice.
singular wallet create --vault alice.vault --network-magic 42
```

Bob's vault, the same way:

```bash
# The same for Bob: bob.vault and his own passphrase.
singular wallet create --vault bob.vault --network-magic 42
```

Alice's public address, read back from her vault. It asks for her passphrase once:

```bash
# Read Alice's address back from her vault, into a shell variable. A public address is safe to share.
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
```

Bob's:

```bash
# The same for Bob.
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
```

The private chain, started in the background. It funds those two addresses with 6 coins of 2000 ada each. Its settings line goes to `devnet.out`:

```bash
# Start a private Cardano test chain (a real node, with a Koios-style web API in front of it).
#   --fund-address ADDRESS:6:2000000000   give ADDRESS 6 coins of 2000 ada (2000000000 lovelace) each
# The trailing & runs it in the background; the line of settings it prints goes to devnet.out,
# its messages to devnet.err. The chain only knows the addresses, never the keys.
devnet --fund-address "$alice_addr:6:2000000000" --fund-address "$bob_addr:6:2000000000" > devnet.out 2> devnet.err &
# Remember its process number, so the last step can stop it.
devnet_pid=$!
```

Wait until the settings line has appeared, then show it:

```bash
# Wait until devnet.out holds the settings, then print them. providerUrl is the address of the chain's web API.
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do sleep 1; done; jq . devnet.out
```
