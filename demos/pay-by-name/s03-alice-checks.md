# Alice checks the registry before she uses it

Alice has read Carol's page. Before she puts a name in this registry, she checks what the page says, with her own settings and her own eyes.

**Her settings.** The registry is the one on Carol's page, named by its address.

```bash alice
settings "$(jq -r .registry ../publish/registry.json)"
```

**Describe it**, as Carol did:

```bash alice
singular registry describe --blueprint "$blueprint" > describe.json
```

`describe` shows which application the registry pins, the program that certifies the keys booked in it. It does not compare that with the application of the release she has, and says so: `applicationPin` reads `not-checked-against-any-blueprint`. The `open-datum` commands know their application and compare it before they read or write anything. `sink-tools check-registry` reads the registry's state output from the chain by its token and decodes the state, and then:

- applies the release's application to this registry's token and compares the result with the one the registry pins
- applies the sink validator to the registry's active policy, which gives the registry sink script, and compares it with the one on Carol's page
- compares the registry on Carol's page with the registry it checked

The second and the third are checks no Singular program makes. It exits with 1 if any of them differs.

```bash alice
sink-tools check-registry describe.json --published ../publish/registry.json
```

The lines to look for: `application: matches`, `published registry: matches` and `published registry sink script: matches`. The last one means Carol's script is exactly what Alice computes by herself.
