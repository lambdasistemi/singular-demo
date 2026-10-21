A registry is a list of keys on the chain, each with a piece of data, its payload. Anyone can add a key, and the person who adds it is its **controller**: the only one who may change it afterwards. Carol creates the registry; from then on it belongs to no one, and what she does for the others is to tell them which registry it is.

**Now Carol.** Go to Carol's window: click `carol`, or press `Ctrl-b 0`.

```bash
carol
```{{exec}}

**The settings.** The programs need to know where the chain answers, which network it is, where the compiled contracts are, and, once there is a registry, its name. They read all of this from a file, `singular.json`, in the folder of the person who runs them. `settings` is a small command these windows have: it writes that file from the chain's settings line. It takes the registry's name when there is one.

```bash
settings
```{{exec}}

**Create.** The registry is made from one unspent coin of Carol's, signed by her vault, and the command returns when everything has landed. The registry keeps its default windows: ten minutes for a booking to be folded into it. `stateToken` is the registry's name.

```bash
open-datum create --vault carol.vault > create.json
```{{exec}}

```bash
jq '{outcome, stateToken}' create.json
```{{exec}}

From now on the registry's name is in her settings file too:

```bash
settings "$(jq -r .stateToken create.json)"
```{{exec}}

**Describe it.** `singular registry describe` reads the registry from the chain: the output that holds its state, and the policies it works with. `activeScript` is the one that matters next: the policy of the tokens that mark live keys. A key is live when an output holds one token named like the key under that policy.

```bash
singular registry describe --blueprint "$blueprint" > describe.json
```{{exec}}

```bash
jq '.registry | {stateToken, stateOutput, activeScript, applicationScript}' describe.json
```{{exec}}

**The sink script.** Money paid to a name waits in a script, the **sink**, closed over two things: the registry's active policy and a name. Carol applies the sink validator to the active policy only. What comes out is the same for every name of this registry; applying a name to it gives that name's sink. `sink-tools` is the tool of this scenario that does this.

```bash
active=$(jq -r .registry.activeScript describe.json)
sink-tools registry-sink --active-policy "$active" > sink-script.hex
wc -c sink-script.hex
```{{exec}}

**Publish.** One file, in the folder `publish`, which stands for the page where Carol would put it: the registry's name and the registry's sink script. Whoever reads it can check it, as the next pages do.

```bash
jq -n --arg t "$(jq -r .stateToken create.json)" --rawfile s sink-script.hex '{"state-token": $t, "sink-script": ($s | rtrimstr("\n"))}' > ../publish/registry.json
```{{exec}}

```bash
jq '{"state-token", "sink-script": (."sink-script"[0:40] + "... (" + (."sink-script" | length | tostring) + " characters)")}' ../publish/registry.json
```{{exec}}
