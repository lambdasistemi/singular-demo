# Singular, on your own chain

Build a registry on a private Cardano chain. Book a key, fold it into the registry, update it, and remove it. Then explore what happens when requests expire or are taken back.

**Everything runs in your personal Codespace.** The chain and its funds belong to this demo; no public network is involved.

## Your controls

Click **▷** beside a command to run it. The adjacent copy icon copies it. Alice, Bob and the chain have separate terminal windows, each with its own shell and files. The next page shows how to switch between them. You can type directly in the terminal too.

The windows carry the vaults' passphrase in `SINGULAR_PASSPHRASE` (`demo`, a throwaway word), so no command asks for it. Run controls pause until the shell is ready; the square stop icon sends Ctrl+C.

## Ready to begin

The Singular kit is prepared during Codespaces setup. Click below to prepare the three windows for the walkthrough. If a previous demo folder exists, it is saved under a dated name before the new one is created:

```bash
bash "$TUTORIAL_ROOT/tutorial/prepare-demo.sh"
```{{exec}}

Choose the right arrow below to start. Work through the commands in order. The rejection and reclaim lessons deliberately wait for the chain's time windows—several minutes altogether.

You can reload this browser tab and keep the same shell. **Stopping the Codespace ends the live chain and shell session.** When finished, use the final lesson to stop the chain, then stop your Codespace.
