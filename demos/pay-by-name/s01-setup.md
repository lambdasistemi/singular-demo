# Setup: five wallets and a private chain

Five people take part. **Carol** creates a registry, a list of names that anyone can read. **Alice** and **Dave** will each hold a name in it. **Bob** owes them both money and will pay them by name. Everything runs on a private test chain: nothing here touches a public network. Each person has a window of their own and a folder of their own, as they would have on their own machines.

A wallet here is a vault: an encrypted key file, opened by a passphrase. The key never leaves the vault. In these windows the passphrase comes from the environment variable `SINGULAR_PASSPHRASE`, so no command asks for it. Every vault here uses `demo`, a throwaway word. The program accepts the variable on a private chain only.

**Carol's vault.** You are in her window, in her folder. `singular wallet create` makes the vault file and prints its address. The `$(...)` keeps the address in `carol_addr`, and `tee` also keeps it in the file `carol.address`.

- `--vault carol.vault`: the file to create
- `--network-magic 42`: the number of this private chain (preprod is 1, mainnet 764824073)

```bash carol
carol_addr=$(singular wallet create --vault carol.vault --network-magic 42 | tee carol.address)
```

The address is public: it is all the chain will ever be told about her.

**Alice's vaults.** She makes two. The second, `alice2`, is a second place to receive money: she uses it in the last step.

```bash alice
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42 | tee alice.address)
```

```bash alice
alice2_addr=$(singular wallet create --vault alice2.vault --network-magic 42 | tee alice2.address)
```

**Dave's vault**, the same way:

```bash dave
dave_addr=$(singular wallet create --vault dave.vault --network-magic 42 | tee dave.address)
```

**Bob's vault:**

```bash bob
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42 | tee bob.address)
```

**The private chain.** `devnet` runs a real Cardano node with a web API in front of it. It only ever sees the addresses, never the keys. It runs in its own window, as a background job, so that the window keeps its prompt. `--fund-address ADDRESS:6:2000000000` gives an address 6 coins of 2000 ada each; `> devnet.out` keeps its one line of settings in a file, `2> devnet.log` its messages in another, and `&` sends it to the background.

```bash chain
devnet --fund-address "$(cat carol/carol.address):6:2000000000" --fund-address "$(cat alice/alice.address):6:2000000000" --fund-address "$(cat alice/alice2.address):6:2000000000" --fund-address "$(cat dave/dave.address):6:2000000000" --fund-address "$(cat bob/bob.address):6:2000000000" > devnet.out 2> devnet.log &
```

**Wait until the settings line has appeared**, then show it. `providerUrl` is where the chain's web API answers.

```bash chain
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do sleep 1; done; jq . devnet.out
```
