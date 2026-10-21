This scenario runs in **tmux**, a program that keeps several terminals in one. The setup has made five windows, each with its own shell:

- `0` `carol`: Carol's window, in her own folder with her own vault
- `1` `alice`: Alice's window
- `2` `dave`: Dave's window
- `3` `bob`: Bob's window
- `4` `chain`: the private chain

Four people, four folders: each keeps the files of what they do, exactly as four people on four machines would. Two more folders stand for what they share: `publish`, the page where Carol publishes the registry, and `messages`, where they leave each other messages. A bar at the bottom of the terminal lists the windows with their numbers and marks the one you are in with a `*`.

Go inside:

```bash
tmux attach -t demo
```{{exec}}

From here on every command you click runs in the window you are in. To change window, type the window's name: `carol`, `alice`, `dave`, `bob` or `chain`. Wherever the story passes from one person to another, the page gives you the word to click.

**Try it.** Go to Bob's window; the `*` in the bar moves to `bob`:

```bash
bob
```{{exec}}

And back to Carol's:

```bash
carol
```{{exec}}

With a keyboard, `Ctrl-b 0` to `Ctrl-b 4` go to the same windows.
