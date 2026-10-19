# Singular Demo 1, step by step

Every grey block has a copy button on GitHub: copy it, paste it into the terminal, run the next one. The blocks are meant to be pasted in order into one terminal. A page with bigger buttons and a done mark per step is in `demo.html`.

Release v0.12.0. Everything runs on a private test chain.

## Before you start: open the shell

Everything below is typed in one terminal. The programs used are `singular`, `open-datum`, `devnet` and `jq`; the shell below puts them on the `PATH` and sets `$blueprint`, the compiled contracts the commands need. Use the nix shell, or the Ubuntu kit if the machine has no Nix.

With Nix, one command opens the shell. The first run fetches about 190 MiB from the binary caches.

```bash
nix develop github:lambdasistemi/singular-demo --accept-flake-config

```

Without Nix, unpack the kit from the release page and use its folder:

```bash
cd singular-demo-v0.12.0-x86_64-linux
export PATH="$PWD/bin:$PATH"
export blueprint="$PWD/share/plutus.json"

```

## Before you start: two programs, one registry

Two command-line programs are used in this demo, `singular` and `open-datum`. Here is what each is for, so every command later has a reason.

**Singular is a registry of keys on Cardano.** A key exists at most once. A request to add or remove a key is first booked and waits; it becomes part of the registry when someone folds it, and the registry has rules for the waiting: a request that nobody folds can be rejected after its windows, and its owner can take it back inside the second window. Singular does not decide what a key means.

**An application gives the keys their meaning.** It decides what a key holds, who may change it, and what happens to the deposit locked with it. Applications plug into the registry and bring their own rules.

**`open-datum` is the application used here.** In it a key holds a piece of data, the payload, that only the key's controller may replace. The controller's deposit stays locked while the key exists and is released when the key is removed. `open-datum` is built on the registry: its commands create a registry tied to this application, and book, change, remove and read the keys.

Which program a command belongs to follows one rule:

- When the command depends on **what a key holds**, it is an `open-datum` command: `create`, `insert`, `update`, `terminate`, `fold` and `inspect`. It knows how the application lays out its data.
- When it does **not** depend on that, it is a `singular` command: making a wallet and reading its address (`singular wallet`), signing a prepared transaction and sending it (`singular wallet sign`, `singular submit`), describing the registry (`singular registry describe`), and the two exits for a stuck request, `singular registry reject` and `singular registry reclaim`.

`create` and `fold` exist in both programs. `singular registry create` takes the application to use as an option; `open-datum create` already knows its own. The demo uses the `open-datum` versions, which build the application's outputs.

The relation in one line: **`singular` runs the registry, `open-datum` is the application that fills it.**

Every write has the same shape: a command books or builds a transaction, a wallet signs it, and it is sent. The few options that every command repeats are explained in step 1.

## Before you start: two ways to sign

Every write in this demo is signed by a wallet, and a command takes exactly one signer. The demo shows two of the ways to give it one, and each of the two people uses one of them throughout.

- **By vault, in one command (Alice).** The command names the vault: `--vault alice.vault`. It builds the transactions, asks for the passphrase, signs, sends, and waits until they have landed.
- **By bundle, in three commands (Bob).** The command names only the wallet's public address and a file: `--wallet-address …` and `--bundle …`. It builds the transactions into the file, signs nothing, sends nothing, and exits with status 19, which means "waiting for signatures". Then `singular wallet sign` signs the bundle and `singular submit` sends it. The program that builds the transactions never touches the key, so the signing can happen wherever the key is. Here it is Bob's vault, on the same machine.

A third way, a plain key file (`--wallet-skey`), exists and is not used here.

**It is who signs that decides the route, not what the transaction is.** The same transactions end up on the chain either way, and any step that signs could use either way. The demo gives Alice the first and Bob the second so that you see both side by side:

- the same command appears in both modes: `open-datum fold` is Bob's bundle in steps 4, 9 and 16 and Alice's vault in step 13, and `open-datum insert` is Alice's vault in step 3 and Bob's bundle in step 12;
- when you see exit status 19 and a `sign` and a `submit`, the wallet is Bob's; when one command does everything and asks for a passphrase, the wallet is Alice's.

**Hardware wallets: not verified.** The bundle and the signature files are standard Cardano text envelopes, so signing on a hardware device may be possible. It has not been tried, and the project does not say it is supported.

## Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file, opened by a passphrase that is typed when a command asks for it. The key never leaves the vault. Alice and Bob each get one. Nothing here touches a public network.

Passphrases are not shown while typed. Use `alice` for Alice and `bob` for Bob, or anything else. The same passphrase is asked again at every command that signs with that vault.

Running this a second time? A vault from an earlier try is refused ("vault already exists"), and it belongs to the earlier chain's addresses. Start clean first: stop the old devnet and remove the demo folder. Skip this the first time.

```bash
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

**Alice's vault.** `singular wallet create` makes the vault file and prints her address. It asks for a new passphrase twice. The `$(...)` keeps the printed address in `alice_addr`.

- `--vault alice.vault`: the file to create
- `--network-magic 42`: the number of this private test chain (preprod is 1, mainnet 764824073)

```bash
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42)

```

**Bob's vault**, the same way, with his own passphrase:

```bash
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42)

```

**Their public addresses.** A public address is safe to share, and it is all the chain will ever be told about a wallet.

```bash
echo "Alice: $alice_addr"; echo "Bob:   $bob_addr"

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

## Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. `create` picks a suitable coin of Alice's by itself and names it in the receipt. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 180 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 180 seconds; raise `process_ms` below if there is a lot to say between the two.

**Two values to keep.** The devnet printed where its web API answers (`providerUrl`) and where its clock data is (`networkTimeDirectory`). Every command below is written out in full and repeats the same groups of options, so these are the only shorthands: plain variables you can print.

- `koios_url`: where the chain's web API answers
- `time_dir`: the chain's clock data (when each slot happens)
- the last line is a check: both lines it prints must be non-empty. If one is empty, paste the block again.

```bash
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
echo "$koios_url"; echo "$time_dir"

```

**How to read the commands from here on.** Each one has the same layout, one group per line:

- the command's own options (what to do: the key, the payload, the windows)
- the registry: `--state-dir` (its journal folder), `--blueprint` (the compiled contracts) and `--state-token` (its name)
- the chain: `--koios-url`, `--network-time` and `--network-magic 42` (this private chain's number)
- the wallet that signs: `--vault` for a wallet that signs in one command (it asks for the passphrase), or `--wallet-address` with `--bundle` for the external way

**Create.** It spends a coin of Alice's as the seed and publishes the registry, signed by her vault. It asks for her passphrase, and returns when everything has landed. There is no registry name yet, so the registry group has only the folder and the contracts.

- `process_ms`: how long the registry has to process a request, in milliseconds
- `retract_ms`: how long after that the owner may take a request back
- both windows are fixed for the registry's whole life
- `seed` in the output is the coin that was spent; `stateToken` is the registry's name

```bash
process_ms=180000; retract_ms=60000
open-datum create \
  --process-time "$process_ms" --retract-time "$retract_ms" \
  --state-dir reg --blueprint "$blueprint" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/01-create.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, seed, stateToken} | with_entries(select(.value != null))' receipts/01-create.json

```

**From now on every command names the registry by its state token**, as `--state-token "$token"`. The token is the registry's name, read from the create receipt:

```bash
token=$(jq -r .stateToken receipts/01-create.json)
echo "$token"

```

Want to see the seed coin before it is spent? Add `--preview` and use `--wallet-address "$alice_addr"` instead of the vault: it reads the chain and writes nothing.

## Step 2: read the registry's page

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. It needs no key and no wallet, because reading is free. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

The create receipt prints this exact command in its field `describeCommand`. It is written out here: the contracts, the registry's name, and the chain.

```bash
singular registry describe \
  --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  | tee receipts/02-describe.txt

```

## Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

**Why two stages, booking and then folding?** The registry's state is one output on the chain, and only a fold changes the registry's root. A booking never touches that output: it only creates a request, an output of its own that holds the deposit. So several people can book at the same time without competing for the registry's state, and one fold then settles up to nine requests together. (On Cardano an output can be spent once, so a single shared state output is exactly what everybody would otherwise queue for.) The price is the wait: until a fold, the request is pending and the key does not exist yet.

**Before you book, read this once.** The next page folds the booking, and its three commands must all run before the fold deadline, so everything that needs explaining is here.

- **A fold** moves pending requests into the registry for good. It is its own command, `open-datum fold`, and anyone may run it: the wallet that folds need not be the one that booked, and the fold's receipt names the requests it settles.
- **Why Bob, and not Alice?** Nothing requires it. The demo has Bob fold Alice's booking to show that a fold is open to every wallet, and to show the second way of signing, Bob's, next to Alice's. Alice could fold her own booking: `open-datum insert` takes a `--fold` switch that books and folds in one command with one wallet. Step 13 has Alice fold Bob's request.
- **Bob signs outside the program.** His fold command only names his address and a bundle file: it builds the transactions, writes them to the file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. That is not an error. Then `singular wallet sign` signs the bundle with his vault (the signatures are called witnesses), and `singular submit` sends it and waits until it has landed.
- **The options on the fold.** `--wallet-address` names who will pay and sign later; `--bundle` is the file the finished, unsigned transactions go to (in `bundles/`); `--out` is where the signatures go (in `witnesses/`); `--receipt` is where the proof of landing goes (in `receipts/`).
- **The clock starts at the booking.** The fold must run within the registry's processing window (3 minutes here). Book, then go straight to the next page and run its three commands without stopping to read.

**The payload**: the data stored under the key, as Plutus data in JSON, constructor 0 holding the integer 42.

```bash
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json

```

**The booking.** Alice signs from her vault and the command sends it; it asks for her passphrase. The request now waits at the registry and is not part of it until it is folded.

- `request` in the output is the pending request (transaction and output number)
- `foldDeadline` is the slot by which it must be folded

```bash
open-datum insert \
  --key alice --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/03-insert-alice.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/03-insert-alice.json

```

## Step 4: fold it (Bob signs outside the program)

Run these three, one after the other, now. They build Bob's fold of the booking, sign it with his vault and send it; what each one is was explained on the previous page.

**Build the fold into a bundle file** (exit status 19, nothing sent). In the output, `settling` is what the fold will settle and `msLeft` the time left before the fold deadline.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle \
  > receipts/04-fold-insert.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/04-fold-insert.json

```

**Bob signs the bundle** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-insert bundles/fold-insert.bundle

```

**Send the signed bundle** and wait until it has landed. `slot` in the output is where on the chain it landed.

```bash
singular submit --witnesses witnesses/fold-insert --receipt receipts/04-fold-insert.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-insert.bundle

```

```bash
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json

```

**If the first command was refused because the window ended.**

The refusal says so in `reason`. Nothing is lost: the booking is still pending and its deposit is locked, and a request nobody folds can be taken back or rejected, which is what steps 11 and 14 show. See where the chain is compared with the booking's deadline:

```bash
jq '{request, foldDeadline}' receipts/03-insert-alice.json

```

```bash
curl -fsS "$koios_url/tip" | jq '.[0] | {abs_slot}'

```

- While the chain's slot is **below** `foldDeadline.slot`, the fold is still possible: run the three commands again.
- Once it is **past** `foldDeadline.slot` and the retract window is still open, Alice takes her request back with a reclaim (the command of step 14, her passphrase). Then book again (step 3) and fold at once:

```bash
singular registry reclaim \
  --request "$(jq -r .request receipts/03-insert-alice.json)" \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/04-reclaim.json

```

- If the retract window has ended too, the reclaim is refused, and the way out is the reject of step 11: any wallet may do it once both windows have passed, and it returns the deposit. Or start the scenario again: a fresh machine takes about a minute.

## Step 5: read the key back

Reading is free and needs no key and no wallet: anyone can check. `inspect` asks the chain for the key's state and prints what it found. The key is now active, with its payload (42), its owner and the deposit that stays locked with it. `root` is a fingerprint of the whole registry.

```bash
open-datum inspect \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/05-inspect.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json

```

## Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change.

**The new payload**: the integer 43.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json

```

**The update.** It asks for Alice's passphrase and takes effect at once.

```bash
open-datum update \
  --key alice --payload payload-new.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/06-update.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, payload} | with_entries(select(.value != null))' receipts/06-update.json

```

**The payload changed, and the root did not.** The first two lines show the payload before and after: 42, then 43. The last two show the registry's root, which is the same on both lines. That is correct. The root is the registry's fingerprint of which keys exist and in what state, so it moves only when a fold settles an insertion or a removal (you will see it change in steps 10, 13 and 16). The payload is not part of it: it lives in the key's own output, which is what the update replaced.

```bash
echo "payload before: $(jq -c .applicationOutput.payload receipts/05-inspect.json)"; echo "payload after:  $(jq -c .payload receipts/06-update.json)"
echo "root before:    $(jq -r .root receipts/05-inspect.json)"; echo "root after:     $(jq -r .root receipts/06-update.json)"

```

## Step 7: read the key back again

The same read as step 5. The payload is now 43; the owner and the deposit are unchanged.

```bash
open-datum inspect \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json

```

## Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. Like an insertion, it waits as a pending request. It asks for Alice's passphrase.

In the output, `released` is the output the fold will release and `deposit` is what comes back to Alice.

```bash
open-datum terminate \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/08-terminate.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, request, released, deposit, foldDeadline} | with_entries(select(.value != null))' receipts/08-terminate.json

```

## Step 9: fold the removal (Bob signs outside the program)

Bob folds the termination, the external way again: build (exit status 19), sign, send. When it lands, the key's token is burned and the deposit goes back to Alice. Run the three pieces before the fold deadline of step 8.

**Build the bundle**, as in step 4: nothing is signed or sent.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-terminate.bundle \
  > receipts/09-fold-terminate.json
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/09-fold-terminate.json

```

**Bob signs it** with his vault (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-terminate bundles/fold-terminate.bundle

```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/fold-terminate --receipt receipts/09-fold-terminate.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-terminate.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/09-fold-terminate.submitted.json

```

**If the first command was refused because the window ended.** The read-back shows it in `reason`: the request's processing deadline is before the moment the fold would be built. Nothing is lost. The termination is still pending and its deposit is locked. A removal cannot be taken back with a reclaim (the project's page says updates and deletions cannot be retracted), so the way out is the reject of step 11. Once both windows have passed, any wallet may reject; here it is Bob's, and it returns the deposit. After that, book the removal again (step 8) and go straight to this page.

```bash
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject-late.bundle \
  > receipts/09-reject.json

```

```bash
singular wallet sign --vault bob.vault --out witnesses/reject-late bundles/reject-late.bundle

```

```bash
singular submit --witnesses witnesses/reject-late \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/reject-late.bundle

```

## Step 10: read the removed key

The key `alice` is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
open-datum inspect \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json

```

## Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

**Alice books `late`** (her passphrase). Nobody will fold it, so the request stays pending.

```bash
open-datum insert \
  --key late --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/11a-insert-late.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/11a-insert-late.json

```

**Bob asks to reject it now**, naming only his address, no key. It is too early, so the program refuses: exit status 10, outcome `client-refusal`, nothing built. The refusal says when the retract window closes: `retractEndsSlot` is the slot where the window closes and `tipSlot` is where the chain is now.

```bash
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11b-reject-too-early.json
jq '{outcome, reason, pending: [.pendingRequests[]? | {request, retractEndsSlot}], tipSlot} | with_entries(select(.value != null))' receipts/11b-reject-too-early.json

```

**A small helper that waits for the chain's own clock.** `wait_for_slot N` asks the chain for its latest slot every 2 seconds until it is past `N`. It uses the chain's clock, like the program does. It is defined once here and used again in step 14.

```bash
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }

```

**Wait until the tip passes the end of the retract window**, named in the refusal. About four minutes.

```bash
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"

```

**Both windows are over.** Bob asks again, the external way. This time the program builds the transaction: it returns the request's locked value to its owner, Alice. Exit status 19, nothing sent yet.

```bash
singular registry reject \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/reject.bundle \
  > receipts/11d-reject.json
jq '{outcome, reason, rejected: [.expected.rejected[]? | {key, request}]} | with_entries(select(.value != null))' receipts/11d-reject.json

```

**Bob signs** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/reject bundles/reject.bundle

```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/reject --receipt receipts/11d-reject.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/reject.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json

```

## Step 12: book the key "bob" (Bob signs outside the program)

The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file instead of a vault, and the bundle holds the booking. Build (exit status 19, nothing sent), sign, send.

**Build the bundle:**

```bash
open-datum insert \
  --key bob --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle \
  > receipts/12-insert-bob.json
jq '{outcome, reason, request: .expected.request, foldDeadline: .expected.foldDeadline} | with_entries(select(.value != null))' receipts/12-insert-bob.json

```

**Bob signs** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/insert-bob bundles/insert-bob.bundle

```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/insert-bob --receipt receipts/12-insert-bob.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/insert-bob.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json

```

## Step 13: fold Bob's key (Alice, vault in one command)

Anyone may fold, and here Alice does. The fold is a single command, because it is her vault that signs and sends it: build, sign, send and wait, with her passphrase. It prints its receipt when it has landed. Run it before the fold deadline of step 12.

In the output, `settled` lists the requests now part of the registry and `root` is the registry's new fingerprint.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/13-fold-bob.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, settled: [.settled[]? | {key, edge}], root} | with_entries(select(.value != null))' receipts/13-fold-bob.json

```

If the fold is refused because the window ended, the recovery is the one at the end of step 4 for a booking of a key (Bob takes his request back with a reclaim while the retract window is open, or any wallet rejects it after both windows), and the one at the end of step 9 when only the reject is left.

## Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

`wait_for_slot` was defined in step 11. In a new terminal, define it again from there.

**Alice books `carol`** (her passphrase). The receipt names the request, which she needs to take it back: `carol_request` keeps it, and `carol_opens` keeps the slot after which the retract window opens.

```bash
open-datum insert \
  --key carol --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14a-insert-carol.json

```

**Keep the request, and the slot after which its retract window opens:**

```bash
carol_request=$(jq -r .request receipts/14a-insert-carol.json); carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/14a-insert-carol.json

```

**Try to reclaim right away.** Refused (exit status 10, `client-refusal`): the retract window has not opened yet.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14b-reclaim-too-early.json

```

**Read what it returned:**

```bash
jq '{outcome, reason} | with_entries(select(.value != null))' receipts/14b-reclaim-too-early.json

```

**Wait for the chain's clock** to pass the end of the processing window. About three minutes.

```bash
wait_for_slot "$carol_opens"

```

**Reclaim**, with one command (her passphrase). Now the retract window is open: Alice takes her request back, and her deposit with it. Her vault signs and sends.

```bash
singular registry reclaim \
  --request "$carol_request" \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/14c-reclaim.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, request, returned} | with_entries(select(.value != null))' receipts/14c-reclaim.json

```

## Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so the registry takes requests again. Alice books one more key, `dave` (her passphrase).

```bash
open-datum insert \
  --key dave --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/15-insert-dave.json

```

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/15-insert-dave.json

```

## Step 16: fold "dave" (Bob signs outside the program), then read it

Bob folds `dave`, external signing as before: build (exit status 19), sign, send. Afterwards an independent read asks the chain for the key and finds it active. That is the last proof that the whole journey worked.

**Build the bundle**, as in steps 4 and 9: nothing is sent yet.

```bash
open-datum fold \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle \
  > receipts/16a-fold-dave.json
jq '{outcome, reason, settling: [.expected.settled[]? | {key, edge}], msLeft: .expected.remainingMs} | with_entries(select(.value != null))' receipts/16a-fold-dave.json

```

**Bob signs** (his passphrase):

```bash
singular wallet sign --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle

```

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/fold-dave --receipt receipts/16a-fold-dave.submitted.json \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  bundles/fold-dave.bundle

```

**Read `dave` back**, the independent check. It should be active.

```bash
open-datum inspect \
  --key dave \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/16b-inspect-dave.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, root}' receipts/16b-inspect-dave.json

```

If the first command is refused because the window ended, the recovery is at the end of step 4 for a booking of a key (Alice reclaims while the retract window is open) and at the end of step 9 for the reject.

## Extra: look at the wallets

The next three pages are optional extras. Skip them in a short demo; the journey is complete without them.

A wallet holds outputs: coins at its address, each one named by the transaction that created it and an index. The devnet's web API lists them. Run this now to see what each wallet starts with, and again whenever you like, for instance after step 16, to see what the journey cost: deposits locked in requests, fees paid, tokens received.

**A small helper** that asks the chain for the outputs at an address and prints a short form. `total_ada` is what the wallet holds; each line of `utxos` is one output: the transaction that made it, its index, its ada and any tokens.

```bash
wallet_show() { curl -fsS -X POST "$koios_url/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" | jq '{outputs: length, total_ada: ([.[] | (.value|tonumber)] | add / 1000000), utxos: [.[] | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000), tokens: [.asset_list[]? | .asset_name[0:8]]}]}'; }

```

**Alice's wallet**, from her public address. No passphrase is needed to look. At the start she holds six outputs of 2000 ada.

```bash
wallet_show "$alice_addr"

```

**Bob's wallet**, the same way:

```bash
wallet_show "$bob_addr"

```

**The chain's own clock**, for reference. It is what the program uses to judge windows: the slot is the chain's unit of time.

```bash
curl -fsS "$koios_url/tip" | jq '.[0] | {abs_slot, block_no}'

```

## Extra: look inside the transactions

Everything the demo sent is a real transaction on the devnet, and each can be examined: what the program prepared, which transaction landed and where, and what the chain says about it. Run these any time after step 4.

**What a prepared transaction is for.** A bundle is a JSON file written by a command run with `--bundle`. Its `effects` say in plain words what each transaction does, and `deadline` is the slot by which it must be sent.

```bash
jq '.transactions[] | {effects, deadline}' bundles/fold-insert.bundle

```

**Which transaction landed, and where.** The landing receipt names each transaction by its `identity` (its hash, the name to look it up by), the slot and block it is in, and how many blocks have been built on top since.

```bash
jq '.submissions[]? | {transaction: .identity, slot: .chainPoint.slot, block: .chainPoint.blockHash[0:12], confirmations}' receipts/04-fold-insert.submitted.json

```

**Every transaction of the demo**, in the order of the receipts. The loop walks all receipts and prints the transactions each one landed.

```bash
for f in receipts/*.json; do jq -r --arg f "$f" '.submissions[]? | "\($f)  \(.identity)  slot \(.chainPoint.slot)"' "$f"; done

```

**What the chain says about one of them.** The devnet's web API answers the same query a public Koios does. Take the first transaction of the step 4 fold and ask the chain about it. The full answer is kept in `receipts/tx-info.json`.

```bash
tx=$(jq -r '.submissions[0].identity' receipts/04-fold-insert.submitted.json)
curl -fsS -X POST "$koios_url/tx_info" -H 'content-type: application/json' -d "{\"_tx_hashes\":[\"$tx\"]}" > receipts/tx-info.json

```

The short form shows where the money comes from and goes to, which tokens move, and which outputs carry data:

```bash
jq '.[0] | {tx_hash, block_height, absolute_slot, inputs: [.inputs[] | {from: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000)}], outputs: [.outputs[] | {to: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000), tokens: [.asset_list[].asset_name[0:8]], has_data: (.inline_datum != null)}]}' receipts/tx-info.json

```

`jq . receipts/tx-info.json` prints all of it. The data on an output is shown as raw bytes; `open-datum inspect` (step 5) prints the same data decoded. This devnet's web API does not report fees or times.

## Extra: a new terminal in the middle

The values below live only in the terminal where they were pasted: the two addresses, the chain's settings and the registry's name. In a new terminal, or after leaving and re-entering the nix shell, paste this first. It rebuilds them from the files in the demo folder, and needs the devnet and the registry from the steps above to be still there.

- `cd ~/singular-demo-run`: back to the demo folder
- the two `singular wallet address` lines read the public addresses from the vaults; each asks for its passphrase once
- `koios_url` and `time_dir` are the two values of step 1
- `token` is the registry's name, read from the create receipt

```bash
cd ~/singular-demo-run
alice_addr=$(singular wallet address --vault alice.vault --network-magic 42)

```

**Bob's, the same way:**

```bash
bob_addr=$(singular wallet address --vault bob.vault --network-magic 42)

```

**Then:**

```bash
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
token=$(jq -r .stateToken receipts/01-create.json)

```

Steps 11 and 14 also use the `wait_for_slot` helper; paste its block from step 11 if it is missing.

## Finish: stop the devnet

The devnet was started in the background at the beginning. This stops it and its node. The receipts stay in `receipts/`, the bundles in `bundles/`, the signatures in `witnesses/`.

```bash
kill "$devnet_pid"

```
