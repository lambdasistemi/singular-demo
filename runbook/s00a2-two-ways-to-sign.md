# Before you start: two ways to sign

Every write in this demo is signed by a wallet, and a command takes exactly one signer. The demo shows two of the ways to give it one, and each of the two people uses one of them throughout.

- **By vault, in one command (Alice).** The command names the vault: `--vault alice.vault`. It builds the transactions, asks for the passphrase, signs, sends, and waits until they have landed.
- **By bundle, in three commands (Bob).** The command names only the wallet's public address and a file: `--wallet-address …` and `--bundle …`. It builds the transactions into the file, signs nothing, sends nothing, and exits with status 19, which means "waiting for signatures". Then `singular wallet sign` signs the bundle and `singular submit` sends it. The program that builds the transactions never touches the key, so the signing can happen wherever the key is. Here it is Bob's vault, on the same machine.

A third way, a plain key file (`--wallet-skey`), exists and is not used here.

**It is who signs that decides the route, not what the transaction is.** The same transactions end up on the chain either way, and any step that signs could use either way. The demo gives Alice the first and Bob the second so that you see both side by side:

- the same command appears in both modes: `open-datum fold` is Bob's bundle in steps 4, 9 and 16 and Alice's vault in step 13, and `open-datum insert` is Alice's vault in step 3 and Bob's bundle in step 12;
- when you see exit status 19 and a `sign` and a `submit`, the wallet is Bob's; when one command does everything and asks for a passphrase, the wallet is Alice's.

**Hardware wallets: not verified.** The bundle and the signature files are standard Cardano text envelopes, so signing on a hardware device may be possible. It has not been tried, and the project does not say it is supported.
