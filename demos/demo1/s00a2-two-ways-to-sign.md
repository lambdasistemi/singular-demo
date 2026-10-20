# Before you start: two ways to sign

Every write in this demo is signed by a wallet, and a command takes exactly one signer. The demo shows two of the ways to give it one, and each of the two people uses one of them throughout.

- **By vault, in one command (Alice).** The command names the vault: `--vault alice.vault`. It builds the transactions, asks for the passphrase, signs, sends, and waits until they have landed.
- **By bundle, in three commands (Bob).** The command names only the wallet's public address and a file: `--wallet-address …` and `--bundle …`. It builds the transactions into the file, signs nothing, sends nothing, and exits with status 19, which means "waiting for signatures". Then `singular wallet sign` signs the bundle and `singular submit` sends it. The program that builds the transactions never touches the key, so the signing can happen wherever the key is. Here it is Bob's vault, on the same machine.

**It is who signs that decides the route, not what the transaction is.** The same transactions end up on the chain either way, and any step that signs could use either way. The demo gives Alice the first and Bob the second so that you see both side by side. When you see exit status 19 and a `sign` and a `submit`, the wallet is Bob's; when one command does everything and asks for a passphrase, the wallet is Alice's.

Both routes are described in the documentation: the [vault](https://lambdasistemi.github.io/singular/docs/singular-node/#keeping-your-signing-key-in-an-encrypted-vault) and the [bundle](https://lambdasistemi.github.io/singular/docs/singular-node/#signing-a-bundle-of-unsigned-transactions-offline).
