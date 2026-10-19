# Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file, opened by a passphrase that is typed when a command asks for it. The key never leaves the vault. Alice and Bob each get one. Nothing here touches a public network.

Passphrases are not shown while typed. Use `alice` for Alice and `bob` for Bob, or anything else. The same passphrase is asked again at every command that signs with that vault.

Running this a second time? A vault from an earlier try is refused ("vault already exists"), and it belongs to the earlier chain's addresses. Start clean first: stop the old devnet and remove the demo folder. Skip this the first time.

```bash skip
kill "$devnet_pid" 2>/dev/null; cd ~ && rm -rf ~/singular-demo-run
```

**A folder of your own.** Everything the demo writes stays in it:

- `receipts/`: what each command printed, one JSON file per command, kept to read afterwards
- `bundles/`: transactions a command has built but not signed (written by `--bundle`)
- `witnesses/`: the signatures Bob makes for a bundle (written by `wallet sign`)

```bash
mkdir -p ~/singular-demo-run && cd ~/singular-demo-run
mkdir -p receipts bundles witnesses
```

**Alice's vault.** `singular wallet create` makes the vault file and prints her address. It asks for a new passphrase twice.

- `--vault alice.vault`: the file to create
- `--network-magic 42`: the number of this private test chain (preprod is 1, mainnet 764824073)

```bash
singular wallet create --vault alice.vault --network-magic 42
```

**Bob's vault**, the same way, with his own passphrase:

```bash
singular wallet create --vault bob.vault --network-magic 42
```

**Their public addresses**, read back from the vaults into shell variables. A public address is safe to share. Each command asks for the passphrase once.

```bash
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)
```

```bash
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)
```

**The private chain**, started in the background. `devnet` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the addresses, never the keys.

- `--fund-address ADDRESS:6:2000000000`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- `> devnet.out`: its one line of settings goes to this file, its messages to `devnet.err`
- `&`: runs it in the background
- `devnet_pid=$!`: remembers its process number, so the last step can stop it

```bash
devnet --fund-address "$alice_addr:6:2000000000" --fund-address "$bob_addr:6:2000000000" > devnet.out 2> devnet.err &
devnet_pid=$!
```

**Wait until the settings line has appeared**, then show it. `providerUrl` is where the chain's web API answers.

```bash
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do sleep 1; done; jq . devnet.out
```
