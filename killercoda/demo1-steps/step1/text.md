This scenario runs in **tmux**, a program that keeps several terminals in one. The setup has made three windows, each with its own shell:

- `0` `alice`: Alice's window, in her own directory with her own vault and receipts
- `1` `bob`: Bob's window, in his own directory
- `2` `chain`: the private chain

Two people, two directories: each keeps the files of what they do, exactly as two people on two machines would. A bar at the bottom of the terminal lists the windows with their numbers and marks the one you are in with a `*`.

Go inside:

```bash
tmux attach -t demo
```{{exec}}

From here on every command you click runs in the window you are in. To change window, type the window's name: `alice`, `bob` or `chain`. Wherever the story passes from one person to the other, the page gives you the word to click.

**Try it.** Go to Bob's window; the `*` in the bar moves to `bob`:

```bash
bob
```{{exec}}

And back to Alice's:

```bash
alice
```{{exec}}

With a keyboard, `Ctrl-b 0`, `Ctrl-b 1` and `Ctrl-b 2` go to the same windows.
