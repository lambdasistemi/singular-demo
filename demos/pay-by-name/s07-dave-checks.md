# Dave checks the registry Bob named

Dave has no name yet. Bob's message tells him which registry to use, and he does what Alice did before him: he checks it.

```bash { window=dave }
cat ../messages/bob-to-dave.json
```

His settings take the registry's address from Bob's message. The page where Carol published the registry is the same one; the check below compares the two.

```bash { window=dave }
settings "$(jq -r .registry ../messages/bob-to-dave.json)"
```

```bash { window=dave }
singular registry describe --blueprint "$blueprint" > describe.json
```

```bash { window=dave }
sink-tools check-registry describe.json --published ../publish/registry.json
```

If the message had named another registry than the one on Carol's page, the check would have said that the published registry is not the registry checked, and the command would have exited with 1.
