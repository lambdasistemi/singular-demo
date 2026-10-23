# Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file, opened by a passphrase. The key never leaves the vault. Alice and Bob each get one. Nothing here touches a public network.

On a private chain the passphrase comes from the environment variable `SINGULAR_PASSPHRASE`, so no command asks for it. Both vaults here use `demo`, a throwaway word. The program accepts the variable on a private chain only.

Running this a second time? A vault from an earlier try is refused ("vault already exists"), and it belongs to the earlier chain's addresses. Start clean first: stop the old devnet and play again in a fresh run folder. Skip this the first time.

```bash { window=chain mode=show }
kill "$devnet_pid" 2>/dev/null
```

**A folder of your own.** The run folder holds one directory for Alice and one for Bob, each with the folders for their receipts, bundles and witnesses and an empty settings file of their own (`alice/alice.json`, `bob/bob.json`), and the shell setup every window starts with. The set-up script made them before the first page.

**Load the shell setup in each window.** One block per window sources it: the run folder, the passphrase, the helpers (`koios_url`, `wait_for_slot`, `wallet_show`), the window's settings file, and the two words `alice` and `bob`, which pin the variable `SINGULAR_CONFIG` to Alice's file and Bob's file. Everything below relies only on what these three blocks load.

```bash { window=alice }
. ../stepper.sh
```

```bash { window=bob }
. ../stepper.sh
```

```bash { window=chain }
. ./stepper.sh
```

**Alice's vault.** `singular wallet create` makes the vault file and prints her address. The `$(...)` keeps the printed address in `alice_addr`, and `tee` also keeps it in the file `alice.address`, which the chain window and the later pages read.

- `--vault alice.vault`: the file to create, in her own directory
- `--network-magic 42`: the number of this private test chain (preprod is 1, mainnet 764824073)

```bash { window=alice }
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42 | tee alice.address)
```

**Bob's vault**, the same way, in his own directory:

```bash { window=bob }
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42 | tee bob.address)
```

**Their public addresses.** A public address is safe to share, and it is all the chain will ever be told about a wallet.

```bash { window=alice }
echo "Alice: $(cat alice.address)"; echo "Bob:   $(cat ../bob/bob.address)"
```

**The private chain**, started in the background. `devnet` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the addresses, never the keys.

- `--fund-address ADDRESS:6:2000000000`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- `$(cat alice/alice.address)`: the address, read from the file Alice's window wrote (Bob's the same way)
- `> devnet.out`: its one line of settings goes to this file, its messages to `devnet.err`
- `&`: runs it in the background
- `devnet_pid=$!`: remembers its process group. A trap stops the whole group when this shell exits, so an unattended run leaves nothing behind (the node outlives its wrapper); the last step shows the manual stop

```bash { window=chain }
devnet --fund-address "$(cat alice/alice.address):6:2000000000" --fund-address "$(cat bob/bob.address):6:2000000000" > devnet.out 2> devnet.err &
devnet_pid=$!
trap 'kill -TERM -- -"$devnet_pid" 2>/dev/null' EXIT
```

**Wait until the settings line has appeared**, then show it. `providerUrl` is where the chain's web API answers. If the devnet dies first, the wait stops at once and shows the devnet's messages instead of hanging.

```bash { window=chain }
devnet_gone=0
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do
  kill -0 "$devnet_pid" 2>/dev/null || { devnet_gone=1; break; }
  sleep 1
done
if [ "$devnet_gone" = 1 ]; then echo "the devnet died before its settings line appeared; its messages:"; cat devnet.err; false; else jq . devnet.out; fi
```
