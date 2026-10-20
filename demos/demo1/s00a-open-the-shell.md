# Before you start: open the shell

Everything below is typed in one terminal. The programs used are `singular`, `open-datum`, `devnet` and `jq`; the shell below puts them on the `PATH` and sets `$blueprint`, the compiled contracts the commands need. Use the nix shell, or the Ubuntu kit if the machine has no Nix.

With Nix, one command opens the shell. The first run fetches about 190 MiB from the binary caches.

```bash skip
nix develop github:lambdasistemi/singular-demo --accept-flake-config
```

Without Nix, unpack the kit from the release page and use its folder:

```bash skip
cd singular-demo-@VERSION@-x86_64-linux
export PATH="$PWD/bin:$PATH"
export blueprint="$PWD/share/plutus.json"
```
