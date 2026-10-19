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

## Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. A preview comes first. It reads the chain, writes nothing, and shows which seed Alice's address would use and what the registry would be called. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 120 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 120 seconds; raise `process_ms` if there is a lot to say between the two.

```bash
# Which chain to talk to: the settings the devnet printed.
koios_url=$(jq -r .providerUrl devnet.out)
time_dir=$(jq -r .networkTimeDirectory devnet.out)
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)
# Alice signs from her vault in one command; this is the option set every Alice command uses.
alice=(--vault alice.vault --passphrase-fd 3)

# 1a. Preview: no signing, nothing written.
open-datum create --preview --state-dir reg --blueprint "$blueprint" "${provider[@]}" --wallet-address "$alice_addr" > receipts/01a-preview.json
jq '{seed, stateToken}' receipts/01a-preview.json

# 1b. Create: spends the seed coin and publishes the registry. It returns when everything has landed.
seed=$(jq -r .seed receipts/01a-preview.json)
process_ms=120000   # time the registry has to process a request
retract_ms=60000    # time after that in which the owner may take it back
open-datum create --seed "$seed" --process-time "$process_ms" --retract-time "$retract_ms" \
  --state-dir reg --blueprint "$blueprint" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/01b-create.json
jq '{outcome, stateToken}' receipts/01b-create.json

# From now on every command names the registry by its state token.
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")
```

## Step 2: read the registry's page

The registry describes itself: which registry this is, which release of Singular runs it, its rules and what it holds now. The create receipt contains the exact command, in its field `describeCommand`, and this runs it as printed. The page is read from the chain's provider, so it is what the chain says and not a signed statement.

```bash
eval "$(jq -r .describeCommand receipts/01b-create.json)"
```

## Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

```bash
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
open-datum insert "${registry[@]}" --key alice --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/03-insert-alice.json
jq '{outcome, request, foldDeadline}' receipts/03-insert-alice.json
```

## Step 4: fold it (Bob signs outside the program)

A fold moves pending requests into the registry for good. Anyone may do it, and here Bob does, the external way: his command only names his address and a bundle file. It builds the transactions, writes them into that file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. It is not an error.

Then Bob signs the bundle with his vault, and the signed bundle is sent; the send waits until the transactions have landed. Run all three before the fold deadline of step 3.

```bash
# 4a. Build the fold into a bundle file (exit status 19).
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle > receipts/04-fold-insert.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/04-fold-insert.json

# 4b. Bob signs the bundle with his vault (witnesses = signatures).
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/fold-insert bundles/fold-insert.bundle 3< bob.passphrase

# 4c. Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-insert "${provider[@]}" --receipt receipts/04-fold-insert.submitted.json bundles/fold-insert.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json
```

## Step 5: read the key back

Reading is free and needs no key and no wallet. `inspect` asks the chain for the key's state and prints what it found: the key is now active, with its payload, its owner and the deposit that stays locked with it.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/05-inspect.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json
```

## Step 6: change the data (Alice)

Alice, as the key's controller, replaces the payload with 43. Only she may; nobody else's signature would be accepted. An update is immediate, with no booking and no fold, and the registry's root does not change. The last line shows the root before and after.

```bash
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
open-datum update "${registry[@]}" --key alice --payload payload-new.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/06-update.json
jq '{outcome, payload}' receipts/06-update.json
echo "root before: $(jq -r .root receipts/05-inspect.json)"; echo "root after:  $(jq -r .root receipts/06-update.json)"
```

## Step 7: read the key back again

The same read: the payload is now 43, and the owner and the deposit are unchanged.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json
```

## Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. The receipt names the pending request, the live output the fold will release, and the deposit that will come back to her.

```bash
open-datum terminate "${registry[@]}" --key alice "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/08-terminate.json
jq '{outcome, request, released, deposit, foldDeadline}' receipts/08-terminate.json
```

## Step 9: fold the removal (Bob signs outside the program)

Bob folds the termination, the external way again: build (exit status 19), sign, send. When it lands, the key's token is burned and the deposit goes back to Alice. Run all three before the fold deadline of step 8.

```bash
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-terminate.bundle > receipts/09-fold-terminate.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/09-fold-terminate.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/fold-terminate bundles/fold-terminate.bundle 3< bob.passphrase
singular submit --witnesses witnesses/fold-terminate "${provider[@]}" --receipt receipts/09-fold-terminate.submitted.json bundles/fold-terminate.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/09-fold-terminate.submitted.json
```

## Step 10: read the removed key

The key is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json
```

## Step 11: a request nobody folded: wait out its windows, then reject it

What if nobody folds a request? Alice books the key `late` and nobody touches it. A request that stays pending past its two windows (processing, then retract) blocks the registry, and the cure is a reject, which sends the deposit back to the owner. While a window is still open the program refuses to build it, and says so: that refusal comes first. Windows are judged by the chain's own latest block (its tip), never by this computer's clock.

```bash
# 11a. Alice books "late". Nobody will fold it.
open-datum insert "${registry[@]}" --key late --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/11a-insert-late.json
jq '{request, foldDeadline}' receipts/11a-insert-late.json

# 11b. Bob asks to reject it now. Refused (exit status 10) and nothing is built: it is still inside its windows.
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11b-reject-too-early.json
jq '{outcome, pending: [.pendingRequests[] | {request, retractEndsSlot}], tipSlot}' receipts/11b-reject-too-early.json

# 11c. Wait for the chain's own clock: the tip must pass the end of the retract window (about three minutes).
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)"
```

Both windows are over. Bob asks again, the external way, and this time the program builds the transaction: it returns the request's locked value to its owner, Alice. Build (exit status 19), sign, send.

```bash
singular registry reject "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/reject.bundle > receipts/11d-reject.json
jq '{outcome, rejected: [.expected.rejected[] | {key, request}]}' receipts/11d-reject.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/reject bundles/reject.bundle 3< bob.passphrase
singular submit --witnesses witnesses/reject "${provider[@]}" --receipt receipts/11d-reject.submitted.json bundles/reject.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/11d-reject.submitted.json
```

## Step 12: book the key "bob" (Bob signs outside the program)

The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file, and the bundle holds the booking. Build (exit status 19), sign, send.

```bash
open-datum insert "${registry[@]}" --key bob --payload payload.json "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle > receipts/12-insert-bob.json
jq '{outcome, request: .expected.request, foldDeadline: .expected.foldDeadline}' receipts/12-insert-bob.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/insert-bob bundles/insert-bob.bundle 3< bob.passphrase
singular submit --witnesses witnesses/insert-bob "${provider[@]}" --receipt receipts/12-insert-bob.submitted.json bundles/insert-bob.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json
```

## Step 13: fold Bob's key (Alice, vault in one command)

Alice folds Bob's request. Here the fold is a single command, because it is her vault that signs and sends it, and it prints its receipt when it has landed. Run it before the fold deadline of step 12.

```bash
open-datum fold "${registry[@]}" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/13-fold-bob.json
jq '{outcome, settled: [.settled[] | {key, edge}], root}' receipts/13-fold-bob.json
```

## Step 14: take back a request: wait for the retract window, then reclaim it

The other way out of a pending request is for its owner to take it back. That is a reclaim, and it is only allowed in the retract window: after the registry's processing window has ended and before the retract window ends. Alice books `carol`, and nobody folds it. Reclaiming straight away is refused, because the processing window is still open. Once the chain tip passes the processing deadline, Alice can take the request back.

```bash
# 14a. Alice books "carol". The receipt names the request, which she will need to take it back.
open-datum insert "${registry[@]}" --key carol --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14a-insert-carol.json
carol_request=$(jq -r .request receipts/14a-insert-carol.json)
carol_opens=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
jq '{request, foldDeadline}' receipts/14a-insert-carol.json

# 14b. Reclaim right away: refused (exit status 10), the processing window is still open.
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14b-reclaim-too-early.json
jq '{outcome, reason}' receipts/14b-reclaim-too-early.json

# 14c. Wait for the chain's clock (about two minutes), then reclaim with one command.
wait_for_slot "$carol_opens"
singular registry reclaim "${registry[@]}" --request "$carol_request" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/14c-reclaim.json
jq '{outcome, request, returned}' receipts/14c-reclaim.json
```

`wait_for_slot` was defined in step 11. If this is a new terminal, define it again from there.

## Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so Alice books one more key, `dave`.

```bash
open-datum insert "${registry[@]}" --key dave --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/15-insert-dave.json
jq '{outcome, request, foldDeadline}' receipts/15-insert-dave.json
```

## Step 16: fold "dave" (Bob signs outside the program), then read it

Bob folds `dave`, external signing as before: build (exit status 19), sign, send. Afterwards an independent read asks the chain for the key and finds it active. That is the last proof that the whole journey worked.

```bash
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-dave.bundle > receipts/16a-fold-dave.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/16a-fold-dave.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/fold-dave bundles/fold-dave.bundle 3< bob.passphrase
singular submit --witnesses witnesses/fold-dave "${provider[@]}" --receipt receipts/16a-fold-dave.submitted.json bundles/fold-dave.bundle
open-datum inspect "${registry[@]}" --key dave "${provider[@]}" > receipts/16b-inspect-dave.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, root}' receipts/16b-inspect-dave.json
```

## Finish: stop the devnet

The devnet was started in the background. This stops it and its node. The receipts stay in `receipts/`.

```bash
kill "$devnet_pid"
```
