A wallet here is a vault: an encrypted key file, opened by a passphrase that is typed when a command asks for it. The key never leaves the vault. Nothing here touches a public network.

Passphrases are not shown while typed. Use `alice` for Alice and `bob` for Bob, or anything else; the same one is asked again at every command that signs with that vault.

**Alice's vault.** You are in her window, in her directory. `singular wallet create` makes the vault file and prints her address. It asks for a new passphrase twice. The `$(...)` keeps the printed address in `alice_addr`, and `tee` also keeps it in the file `alice.address`.

- `--vault alice.vault`: the file to create
- `--network-magic 42`: the number of this private test chain (preprod is 1, mainnet 764824073)

```bash
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42 | tee alice.address)
```{{exec}}

The address is public: it is all the chain will ever be told about her.

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

**Bob's vault**, the same way, with his own passphrase:

```bash
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42 | tee bob.address)
```{{exec}}

**The private chain.** `devnet` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the two addresses, never the keys. It runs in its own window, as a background job: the window keeps its prompt.

Go to the chain's window: click `chain`, or press `Ctrl-b 2`.

```bash
chain
```{{exec}}

Then run it:

- `--fund-address ADDRESS:6:2000000000`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- `$(cat alice/alice.address)`: the address, read from the file Alice's window wrote (Bob's the same way)
- `> devnet.out`: its one line of settings goes to this file
- `2> devnet.log`: its messages go to this file
- `&`: runs it in the background, so that the window gets its prompt back and the chain keeps running

```bash
devnet --fund-address "$(cat alice/alice.address):6:2000000000" --fund-address "$(cat bob/bob.address):6:2000000000" > devnet.out 2> devnet.log &
```{{exec}}

The chain keeps running: leave it.

Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

**Wait until the settings line has appeared**, then show it. `providerUrl` is where the chain's web API answers.

```bash
until jq -e .providerUrl ../devnet.out >/dev/null 2>&1; do sleep 1; done; jq . ../devnet.out
```{{exec}}

**The chain's log.** The chain's messages went to `devnet.log`. Show the last lines:

```bash
tail -n 20 ../devnet.log
```{{exec}}
