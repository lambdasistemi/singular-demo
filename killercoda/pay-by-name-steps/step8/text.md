**Now Dave.** Go to Dave's window: click `dave`, or press `Ctrl-b 2`.

```bash
dave
```{{exec}}

Dave has no name yet. Bob's message tells him which registry to use, and he does what Alice did before him: he checks it.

```bash
cat ../messages/bob-to-dave.json
```{{exec}}

His settings take the registry's address from Bob's message. The page where Carol published the registry is the same one; the check below compares the two.

```bash
settings "$(jq -r .registry ../messages/bob-to-dave.json)"
```{{exec}}

```bash
singular registry describe --blueprint "$blueprint" > describe.json
```{{exec}}

```bash
sink-tools check-registry describe.json --published ../publish/registry.json
```{{exec}}

If the message had named another registry than the one on Carol's page, the check would have said that the published registry is not the registry checked, and the command would have exited with 1.
