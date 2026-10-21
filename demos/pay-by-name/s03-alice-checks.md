# Alice checks the registry before she uses it

Alice has read Carol's page. Before she puts a name in this registry, she checks what the page says, with her own settings and her own eyes.

**Her settings.** The registry's name is the one on Carol's page.

```bash alice
settings "$(jq -r '."state-token"' ../publish/registry.json)"
```

**Describe it**, as Carol did:

```bash alice
singular registry describe --blueprint "$blueprint" > describe.json
```

`describe` shows which application the registry pins, the program that certifies the keys booked in it. It does not compare that with the application of the release she has: nothing stops a registry from pinning another one. So the check is separate. `sink-tools check-registry` reads the registry's state output from the chain by its token and decodes the state, and then:

- applies the release's application to this registry's name and compares the result with the one the registry pins
- compares the active policy it reads with the one `describe` printed
- applies the sink validator to that active policy, which gives the registry sink script, and compares it with the one on Carol's page

It exits with 1 if any of them differs.

```bash alice
sink-tools check-registry describe.json --published ../publish/registry.json
```

The lines to look for: `application: matches`, `active policy: matches describe` and `published registry sink script: matches`. The last one means Carol's script is exactly what Alice computes by herself.
