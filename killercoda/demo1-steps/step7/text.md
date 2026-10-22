Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

**Why two stages, booking and then folding?** The registry's state is one output on the chain, and only a fold changes the registry's root. A booking never touches that output: it only creates a request, an output of its own that holds the deposit. So several people can book at the same time without competing for the registry's state, and one fold then settles up to nine requests together. The price is the wait: until a fold, the request is pending and the key does not exist yet. The [documentation](https://lambdasistemi.github.io/singular/docs/singular-node/#booking-and-folding); the contracts that hold a request and fold it are [request.ak](https://github.com/lambdasistemi/singular/blob/v0.16.0/onchain/validators/request.ak) and [fold.ak](https://github.com/lambdasistemi/singular/blob/v0.16.0/onchain/lib/registry/fold.ak).

**Before you book, read this once.** The next page folds the booking, and its three commands must all run before the fold deadline, so everything that needs explaining is here.

- **A fold** moves pending requests into the registry for good. It is its own command, `open-datum fold`, and anyone may run it: the wallet that folds need not be the one that booked, and the fold's receipt names the requests it settles.
- **Why Bob, and not Alice?** Nothing requires it. The demo has Bob fold Alice's booking to show that a fold is open to every wallet, and to show the second way of signing, Bob's, next to Alice's.
- **Bob signs outside the program.** His fold command only names his address and a bundle file: it builds the transactions, writes them to the file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. That is not an error. Then `singular wallet sign` signs the bundle with his vault (the signatures are called witnesses), and `singular submit` sends it and waits until it has landed.
- **The options on the fold.** `--wallet-address` names who will pay and sign later; `--bundle` is the file the finished, unsigned transactions go to (in `bundles/`); `--out` is where the signatures go (in `witnesses/`); `--receipt` is where the proof of landing goes (in `receipts/`).
- **The clock starts at the booking.** The fold must run within the registry's processing window (3 minutes here). Book, then go straight to the next page and run its three commands without stopping to read.

**The payload**: the data stored under the key, as Plutus data in JSON, constructor 0 holding the integer 42.

```bash
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
```{{exec}}

**The booking.** Alice signs from her vault and the command sends it. The request now waits at the registry and is not part of it until it is folded.

- `request` in the output is the pending request (transaction and output number)
- `foldDeadline` is the slot by which it must be folded

```bash
open-datum insert \
  --key alice --payload payload.json \
  --vault alice.vault \
  > receipts/03-insert-alice.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/03-insert-alice.json
```{{exec}}
