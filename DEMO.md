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

## Before you start: two wallets and a private chain

A wallet here is a vault: an encrypted key file opened by a passphrase that is typed when the command asks for it, and the key never leaves the vault. Alice and Bob each get one. Nothing here touches a public network.

Passphrases are not shown while typed. Use `alice` for Alice and `bob` for Bob, or anything else; the same one is asked again at every command that signs with that vault.

Running this a second time? A vault from an earlier try is refused ("vault already exists"), and it belongs to the earlier chain's addresses. Start clean first: stop the old devnet and remove the demo folder. Skip this the first time.

```bash
# Stop the old devnet if one is still running, then remove the demo folder of the earlier try.
kill "$devnet_pid" 2>/dev/null; cd ~ && rm -rf ~/singular-demo-run

```

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

## Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 120 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 120 seconds; raise `process_ms` below if there is a lot to say between the two.

Which chain to talk to: the settings the devnet printed.

```bash
# Read the chain's settings from the line the devnet printed:
#   providerUrl          where the chain's web API answers
#   networkTimeDirectory the chain's clock data (when each slot happens)
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
# From now on "${provider[@]}" stands for these three options, which every command needs:
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)

```

The options every Alice command uses: sign from her vault, in one command.

```bash
# "${alice[@]}" stands for: sign with Alice's vault (it asks for her passphrase), then send.
alice=(--vault alice.vault)

```

Preview first. It reads the chain, writes nothing, and shows which seed Alice's address would use and what the registry would be called:

```bash
# Preview: a dry look. Nothing is signed or sent, so only her public address is needed.
#   --state-dir reg    the folder where this registry's own journal is kept (it is created)
#   --blueprint        the compiled contracts the registry is built from
open-datum create --preview --state-dir reg --blueprint "$blueprint" "${provider[@]}" --wallet-address "$alice_addr" > receipts/01a-preview.json
# seed = the coin that will be spent; stateToken = the registry's name
jq '{seed, stateToken}' receipts/01a-preview.json

```

The two windows, in milliseconds:

```bash
# process_ms: how long the registry has to process a request. retract_ms: how long after that its owner may take it back.
process_ms=120000; retract_ms=60000

```

Create: it spends the seed coin and publishes the registry. It asks for Alice's passphrase, and returns when everything has landed:

```bash
# Create the registry. --seed names the coin to spend; the windows are fixed for the registry's whole life.
open-datum create --seed "$(jq -r .seed receipts/01a-preview.json)" --process-time "$process_ms" --retract-time "$retract_ms" --state-dir reg --blueprint "$blueprint" "${provider[@]}" "${alice[@]}" > receipts/01b-create.json
jq '{outcome, stateToken}' receipts/01b-create.json

```

From now on every command names the registry by its state token:

```bash
# "${registry[@]}" stands for: this registry's journal folder, the contracts, and its name (the state token).
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")

```

## Step 2: read the registry's page

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. The create receipt contains the exact command, in its field `describeCommand`, and this runs it as printed. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

```bash
# Run the "singular registry describe" command that the create receipt printed. It needs no key: reading is free.
eval "$(jq -r .describeCommand receipts/01b-create.json)"

```

## Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

The payload:

```bash
# The data stored under the key, as Plutus data in JSON: constructor 0 holding the integer 42.
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json

```

The booking. It asks for Alice's passphrase:

```bash
# Book the insertion of the key "alice" with that payload. Alice signs from her vault and the command sends it.
# The request now waits at the registry; it is not part of the registry until it is folded.
open-datum insert "${registry[@]}" --key alice --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/03-insert-alice.json
# request = the pending request (transaction#output); foldDeadline = the slot by which it must be folded
jq '{outcome, request, foldDeadline}' receipts/03-insert-alice.json

```

## Step 4: fold it (Bob signs outside the program)

A fold moves pending requests into the registry for good. Anyone may do it, and here Bob does, the external way: his command only names his address and a bundle file. It builds the transactions, writes them into that file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. It is not an error.

Then Bob signs the bundle with his vault, and the signed bundle is sent; the send waits until the transactions have landed. Run the three pieces before the fold deadline of step 3.

Build the fold into a bundle file:

```bash
# Fold the pending request. Bob is named only by his public address: no key is used here.
#   --wallet-address  who will pay and sign later
#   --bundle          the file the finished, unsigned transactions are written to (in bundles/)
# It exits with status 19 ("waiting for signatures") and sends nothing.
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle > receipts/04-fold-insert.json
# settling = what the fold will settle; msLeft = time left before the fold deadline
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/04-fold-insert.json

```

Bob signs the bundle with his vault (witnesses are signatures). It asks for Bob's passphrase:

```bash
# Bob signs the bundle with his vault; his key is used inside the command and never leaves it.
#   --out  where the signatures (witnesses) are written, in witnesses/
singular wallet sign --vault bob.vault --out witnesses/fold-insert bundles/fold-insert.bundle

```

Send the signed bundle and wait until it has landed:

```bash
# Send the bundle with Bob's signatures, and wait until the chain has accepted it.
#   --receipt  where the proof of landing is written, in receipts/
singular submit --witnesses witnesses/fold-insert "${provider[@]}" --receipt receipts/04-fold-insert.submitted.json bundles/fold-insert.bundle
# slot = where on the chain it landed
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json

```

## Step 5: read the key back

Reading is free and needs no key and no wallet. `inspect` asks the chain for the key's state and prints what it found: the key is now active, with its payload, its owner and the deposit that stays locked with it.

```bash
# Read the key "alice" from the chain. No wallet and no key: anyone can check.
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/05-inspect.json
# state: active; payload: 42; deposit: what stays locked; root: a fingerprint of the whole registry
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json

```

## Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change.

The new payload:

```bash
# The new data: the integer 43.
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json

```

The update. It asks for Alice's passphrase:

```bash
# Replace the key's data. Only its controller, Alice, can sign this; it takes effect at once.
open-datum update "${registry[@]}" --key alice --payload payload-new.json "${provider[@]}" "${alice[@]}" > receipts/06-update.json
jq '{outcome, payload}' receipts/06-update.json

```

The root before and after is the same:

```bash
# An update changes the key's data but not the registry's root: both lines show the same fingerprint.
echo "root before: $(jq -r .root receipts/05-inspect.json)"; echo "root after:  $(jq -r .root receipts/06-update.json)"

```

## Step 7: read the key back again

The same read: the payload is now 43, and the owner and the deposit are unchanged.

```bash
# The same read as step 5. The payload is now 43; the deposit is unchanged.
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json

```

## Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. The receipt names the pending request, the live output the fold will release, and the deposit that will come back to her. It asks for Alice's passphrase.

```bash
# Book the removal ("terminate") of the key "alice". Like an insertion, it waits as a pending request.
open-datum terminate "${registry[@]}" --key alice "${provider[@]}" "${alice[@]}" > receipts/08-terminate.json
# released = the output the fold will release; deposit = what comes back to Alice
jq '{outcome, request, released, deposit, foldDeadline}' receipts/08-terminate.json

```

## Step 9: fold the removal (Bob signs outside the program)

Bob folds the termination, the external way again: build (exit status 19), sign, send. When it lands, the key's token is burned and the deposit goes back to Alice. Run the three pieces before the fold deadline of step 8.

Build the bundle:

```bash
# Same as step 4: build the fold for Bob into a bundle file (exit status 19, nothing sent).
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-terminate.bundle > receipts/09-fold-terminate.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/09-fold-terminate.json

```

Bob signs it (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/fold-terminate bundles/fold-terminate.bundle

```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-terminate "${provider[@]}" --receipt receipts/09-fold-terminate.submitted.json bundles/fold-terminate.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/09-fold-terminate.submitted.json

```

## Step 10: read the removed key

The key is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
# Read "alice" once more. The state is now terminal: the key is gone for good.
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json

```

## Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

Alice books `late` (her passphrase). Nobody will fold it:

```bash
# Book the key "late". Nobody will fold it, so the request stays pending.
open-datum insert "${registry[@]}" --key late --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/11a-insert-late.json
jq '{request, foldDeadline}' receipts/11a-insert-late.json

```

Bob asks to reject it now. It is refused (exit status 10) and nothing is built, because the request is still inside its windows:

```bash
# Ask to reject the stuck request, as Bob (only his address, no key). Too early: the program refuses
# (exit status 10, "client-refusal"), builds nothing, and says when the retract window closes.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11b-reject-too-early.json
# retractEndsSlot = the slot the window closes at; tipSlot = where the chain is now
jq '{outcome, pending: [.pendingRequests[] | {request, retractEndsSlot}], tipSlot}' receipts/11b-reject-too-early.json

```

A small helper that waits for the chain's own clock to pass a slot (shown once, used here and in step 14):

```bash
# wait_for_slot N: ask the chain for its latest slot every 2 seconds until it is past N.
# It uses the chain's clock, not this computer's, like the program does.
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }

```

Wait until the tip passes the end of the retract window, about three minutes:

```bash
# Wait for the end of the retract window named in the refusal.
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"

```

Both windows are over. Bob asks again, the external way, and this time the program builds the transaction: it returns the request's locked value to its owner, Alice. Build (exit status 19):

```bash
# The same reject command as before. Now it builds the transaction: the deposit goes back to Alice.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11d-reject.json
jq '{outcome, rejected: [.expected.rejected[] | {key, request}]}' receipts/11d-reject.json

```

Bob signs (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/reject bundles/reject.bundle

```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/reject "${provider[@]}" --receipt receipts/11d-reject.submitted.json bundles/reject.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json

```

## Step 12: book the key "bob" (Bob signs outside the program)

The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file, and the bundle holds the booking. Build (exit status 19), sign, send.

Build the bundle:

```bash
# Book the key "bob" as Bob: his address and a bundle file instead of a vault. Exit status 19, nothing sent.
open-datum insert "${registry[@]}" --key bob --payload payload.json "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle > receipts/12-insert-bob.json
jq '{outcome, request: .expected.request, foldDeadline: .expected.foldDeadline}' receipts/12-insert-bob.json

```

Bob signs (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/insert-bob bundles/insert-bob.bundle

```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/insert-bob "${provider[@]}" --receipt receipts/12-insert-bob.submitted.json bundles/insert-bob.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json

```

## Step 13: fold Bob's key (Alice, vault in one command)

Alice folds Bob's request. Here the fold is a single command, because it is her vault that signs and sends it (her passphrase), and it prints its receipt when it has landed. Run it before the fold deadline of step 12.

```bash
# Anyone may fold: here Alice does, with her vault, in one command (build, sign, send, wait).
open-datum fold "${registry[@]}" "${provider[@]}" "${alice[@]}" > receipts/13-fold-bob.json
# settled = the requests now part of the registry; root = the registry's new fingerprint
jq '{outcome, settled: [.settled[] | {key, edge}], root}' receipts/13-fold-bob.json

```

## Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

`wait_for_slot` was defined in step 11. In a new terminal, define it again from there.

Alice books `carol` (her passphrase). The receipt names the request, which she needs to take it back:

```bash
# Book the key "carol". The receipt names the request (transaction#output), which Alice needs to take it back.
open-datum insert "${registry[@]}" --key carol --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/14a-insert-carol.json
# Keep the request, and the slot after which the retract window opens.
carol_request=$(jq -r .request receipts/14a-insert-carol.json); carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{request, foldDeadline}' receipts/14a-insert-carol.json

```

Reclaim right away: refused (exit status 10), because the processing window is still open:

```bash
# Try to take the request back at once. Refused (exit status 10): the retract window has not opened yet.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" > receipts/14b-reclaim-too-early.json
jq '{outcome, reason}' receipts/14b-reclaim-too-early.json

```

Wait for the chain's clock, about two minutes:

```bash
# Wait until the chain's clock passes the end of the processing window.
wait_for_slot "$carol_opens"

```

Reclaim, with one command (her passphrase):

```bash
# Now the retract window is open: Alice takes her request back, and her deposit with it. Her vault signs and sends.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" > receipts/14c-reclaim.json
jq '{outcome, request, returned}' receipts/14c-reclaim.json

```

## Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so Alice books one more key, `dave` (her passphrase).

```bash
# Book the key "dave". The registry takes requests again because the stuck one is gone.
open-datum insert "${registry[@]}" --key dave --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/15-insert-dave.json
jq '{outcome, request, foldDeadline}' receipts/15-insert-dave.json

```

## Step 16: fold "dave" (Bob signs outside the program), then read it

Bob folds `dave`, external signing as before: build (exit status 19), sign, send. Afterwards an independent read asks the chain for the key and finds it active. That is the last proof that the whole journey worked.

Build the bundle:

```bash
# Build Bob's fold of "dave" into a bundle (exit status 19, nothing sent). Same as steps 4 and 9.
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle > receipts/16a-fold-dave.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/16a-fold-dave.json

```

Bob signs (his passphrase):

```bash
# Bob signs the bundle with his vault.
singular wallet sign --vault bob.vault --out witnesses/fold-dave bundles/fold-dave.bundle

```

Send it:

```bash
# Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-dave "${provider[@]}" --receipt receipts/16a-fold-dave.submitted.json bundles/fold-dave.bundle

```

Read `dave` back:

```bash
# The independent check: ask the chain for "dave". It should be active.
open-datum inspect "${registry[@]}" --key dave "${provider[@]}" > receipts/16b-inspect-dave.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, root}' receipts/16b-inspect-dave.json

```

## Optional: look inside the transactions

Everything the demo sent is a real transaction on the devnet, and each can be examined: what the program prepared, which transaction landed and where, and what the chain says about it. Run these any time after step 4.

What a prepared transaction is for. Every bundle file lists, in plain words, the effect of each transaction in it, and its deadline:

```bash
# A bundle is a JSON file written by a command run with --bundle. "effects" says what each transaction does.
jq '.transactions[] | {effects, deadline}' bundles/fold-insert.bundle

```

Which transaction landed, and where. The landing receipt names each transaction by its identity (its hash), the slot and block it is in, and how many blocks have been built on top since:

```bash
# "identity" is the transaction's hash: the name to look it up by.
jq '.submissions[] | {transaction: .identity, slot: .chainPoint.slot, block: .chainPoint.blockHash[0:12], confirmations}' receipts/04-fold-insert.submitted.json

```

Every transaction of the demo, in the order of the receipts:

```bash
# Walk all receipts and print the transactions each one landed.
for f in receipts/*.json; do jq -r --arg f "$f" '.submissions[]? | "\($f)  \(.identity)  slot \(.chainPoint.slot)"' "$f"; done

```

What the chain says about one of them. The devnet's web API answers the same query a public Koios does:

```bash
# Take the first transaction of the step 4 fold, and ask the chain about it.
tx=$(jq -r '.submissions[0].identity' receipts/04-fold-insert.submitted.json)
curl -fsS -X POST "$koios_url/tx_info" -H 'content-type: application/json' -d "{\"_tx_hashes\":[\"$tx\"]}" > receipts/tx-info.json
# Short form: where the money comes from and goes to, which tokens move, and which outputs carry data.
jq '.[0] | {tx_hash, block_height, absolute_slot, inputs: [.inputs[] | {from: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000)}], outputs: [.outputs[] | {to: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000), tokens: [.asset_list[].asset_name[0:8]], has_data: (.inline_datum != null)}]}' receipts/tx-info.json

```

The full answer is in `receipts/tx-info.json`; `jq . receipts/tx-info.json` prints all of it. The data on an output is shown as raw bytes; `open-datum inspect` (step 5) prints the same data decoded. This devnet's web API does not report fees or times.

## Finish: stop the devnet

The devnet was started in the background. This stops it and its node. The receipts stay in `receipts/`, the bundles in `bundles/`, the signatures in `witnesses/`.

```bash
# Stop the private chain started at the beginning.
kill "$devnet_pid"

```
