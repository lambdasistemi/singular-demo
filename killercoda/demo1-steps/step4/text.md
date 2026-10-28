A wallet here is a vault: an encrypted key file, opened by a passphrase. The key never leaves the vault. Carol, Alice and Bob each get one. Nothing here touches a public network.

On a private chain the passphrase comes from the environment variable `SINGULAR_PASSPHRASE`, so no command asks for it. All three vaults here use `demo`, a throwaway word. The program accepts the variable on a private chain only.

Running this a second time? A vault from an earlier try is refused ("vault already exists"), and it belongs to the earlier chain's addresses. Start clean first: stop the old devnet and play again in a fresh run folder. Skip this the first time.

```bash
kill "$devnet_pid" 2>/dev/null
```

**A folder of your own.** The run folder holds one directory for Alice and one for Bob, each with the folders for their receipts, bundles and witnesses and an empty settings file of their own (`alice/alice.json`, `bob/bob.json`), and the shell setup every window starts with. The set-up script made them before the first page.

**Load the shell setup in each window.** One block per window sources it: the run folder, the programs on `PATH`, the passphrase, the helpers (`koios_url`, `wait_for_slot`, `wallet_show`), the window's settings file, and the actor words `carol`, `alice` and `bob`, which select that actor's `SINGULAR_CONFIG`. Everything below relies only on what these four blocks load.

```bash
. ../stepper.sh
```{{exec}}

Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

```bash
. ../stepper.sh
```{{exec}}

Go to Carol's window: click `carol`, or press `Ctrl-b 3`.

```bash
carol
```{{exec}}

```bash
. ../stepper.sh
```{{exec}}

Go to the chain's window: click `chain`, or press `Ctrl-b 2`.

```bash
chain
```{{exec}}

```bash
. ./stepper.sh
```{{exec}}

**Now Alice.** Go to Alice's window: click `alice`, or press `Ctrl-b 0`.

```bash
alice
```{{exec}}

**Alice's vault.** `singular wallet create` makes the vault file and prints her address. The `$(...)` keeps the printed address in `alice_addr`, and `tee` also keeps it in the file `alice.address`, which the chain window and the later pages read.

- `--vault alice.vault`: the file to create, in her own directory
- `--network-magic 42`: the number of this private test chain (preprod is 1, mainnet 764824073)

```bash
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42 | tee alice.address)
```{{exec}}

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

**Bob's vault**, the same way, in his own directory:

```bash
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42 | tee bob.address)
```{{exec}}

**Now Carol.** Go to Carol's window: click `carol`, or press `Ctrl-b 3`.

```bash
carol
```{{exec}}

**Carol's own vault:**

```bash
carol_addr=$(singular wallet create --vault carol.vault --network-magic 42 | tee carol.address)
```{{exec}}

**Now Chain.** Go to the chain's window: click `chain`, or press `Ctrl-b 2`.

```bash
chain
```{{exec}}

**The private chain**, started in the background. `devnet` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the addresses, never the keys.

- `--fund-address ADDRESS:6:2000000000`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- `$(cat alice/alice.address)`: the address, read from the file Alice's window wrote (Bob's the same way)
- `> devnet.out`: its one line of settings goes to this file, its messages to `devnet.err`
- `&`: runs it in the background
- `devnet_pid=$!`: remembers its process group. A trap stops the whole group when this shell exits, so an unattended run leaves nothing behind (the node outlives its wrapper); the last step shows the manual stop

```bash
devnet --fund-address "$(cat alice/alice.address):6:2000000000" --fund-address "$(cat bob/bob.address):6:2000000000" --fund-address "$(cat carol/carol.address):6:2000000000" > devnet.out 2> devnet.err &
devnet_pid=$!
trap 'kill -TERM -- -"$devnet_pid" 2>/dev/null' EXIT
```{{exec}}

**Wait until the settings line has appeared**, then show it. `providerUrl` is where the chain's web API answers. If the devnet dies first, the wait stops at once and shows the devnet's messages instead of hanging.

```bash
devnet_gone=0
until jq -e .providerUrl devnet.out >/dev/null 2>&1; do
  kill -0 "$devnet_pid" 2>/dev/null || { devnet_gone=1; break; }
  sleep 1
done
if [ "$devnet_gone" = 1 ]; then echo "the devnet died before its settings line appeared; its messages:"; cat devnet.err; false; else jq . devnet.out; fi
```{{exec}}
