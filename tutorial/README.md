# Codespaces tutorial prototype

A single-user tutorial with instructions beside an xterm.js terminal. The inline **▷** control inserts a command into the active persistent Bash terminal. The walkthrough has Alice, Bob and chain windows in an isolated tmux session. Variables, background processes and the working directory survive lesson changes and browser reconnects within each window. Commands are disabled while the shell is running a command or waiting for input. You can type, paste and use Ctrl+C directly in the terminal.

## Try it

[Launch the `dev` branch in Codespaces](https://codespaces.new/lambdasistemi/singular-demo?ref=dev&quickstart=1)

**Already have a Codespace?** Run this in its **editor terminal**, then refresh the tutorial:

```bash
git pull --ff-only && bash tutorial/update.sh
```

No container rebuild; this starts a fresh shell/chain session and preserves your files.


1. Sign in to GitHub and create a Codespace on the branch you want (`main` is the published one).
2. Wait for the development container and dependencies to finish installing.
3. The welcome file opens as a rendered Markdown page with your exact **Open your tutorial** link. The tutorial port is also configured to open automatically. The **Ports** panel → **8765** → **Open in Browser** remains a fallback.
4. The kit is already installed. Click the preparation command in the introduction to create the Alice, Bob and chain windows, then use the right arrow to begin. A previous demo folder is preserved under a dated `singular-demo-saved-*` folder.
5. Click the play icon beside each command, in order. The private-chain wallets open with a throwaway passphrase the windows already carry. The copy icon is alongside it; the terminal's square stop icon sends Ctrl+C.
6. Finish the walkthrough and stop the chain, then stop your Codespace from https://github.com/codespaces. Closing the tutorial tab alone does not stop compute usage.

GitHub still requires its sign-in and Codespace creation screens. Once the Codespace is known, its tutorial address is generated automatically from `CODESPACE_NAME` and `GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN`; nobody needs to assemble it manually.

For an existing test Codespace, run this in the **Codespaces editor terminal** (outside the tutorial):

```bash
git pull --ff-only && bash tutorial/update.sh
```

This prepares the kit, installs dependencies only when needed, restarts the tutorial and prints its exact link. Refresh the tutorial tab afterward. **No container rebuild is needed.** Run it before a fresh walkthrough: restarting ends the live shell and chain but preserves your files. The command also works on the original prototype; later updates reuse the dependency fingerprint.

The current container configuration applies automatically to new Codespaces. Existing ones can keep their original launch hooks; `update.sh` and `open.sh` provide the updated entry point immediately.

Keep port 8765 **Private**. This application is a shell for the Codespace owner, not a public multi-user service. Use your personal Codespaces quota for the experiment; the GitHub creation screen shows who pays. Stop the Codespace when done; deleting it also releases its retained storage.

The first build installs Python and Node dependencies. Subsequent starts launch the server without reinstalling them. The 113 MB Singular kit is downloaded during initial Codespaces setup. The introduction prepares the tmux session and checks the kit again for local use or recovery. Its release checksum is pinned in `install-kit.sh`.

## Content

`welcome.md` introduces the demo; `finish.md` appends Codespaces shutdown guidance. The server loads the other lessons directly from `../killercoda/demo1-steps/index.json` (the scenario generated in this repository; `TUTORIAL_SCENARIO` names another) and its Markdown files. Only fenced blocks marked `{{exec}}` receive a Run button. Unmarked commands remain copyable reference material, preserving the upstream scenario's choices.

The scenario is generated from the tutorial's step files by `node demos/demo1/killercoda.js .` and is the one Killercoda plays; nothing is copied by hand. The kit is installed and the three windows are started by the scripts of the play in `demos/demo1/play/`, the same ones the Killercoda machine runs, for the Singular version pinned in `flake.nix`.

## Local use and checks

On Linux with Python 3, its venv package, Node/npm, Bash, curl and jq installed:

```bash
bash tutorial/setup.sh
bash tutorial/start.sh
# Open http://127.0.0.1:8765 in a browser
tutorial/.venv/bin/python tutorial/test_runner.py
```

Stop the running tutorial before running the integration tests because both use port 8765. The update test (`tutorial/.venv/bin/python tutorial/test-update.py`) exercises replacement of a live server while preserving files and reusing dependencies. To restart the server (also starts a fresh shell):

```bash
tutorial/.venv/bin/python tutorial/stop.py
bash tutorial/start.sh
```

The tests check command execution, multiline shell state, hidden input, rejection of clicks during prompts (typed input in the terminal), reconnects, Ctrl+C, origin checks and single-tab ownership. Browser checks also cover inline icon placement, accessible labels, mobile overflow and reconnects. `test-demo.cjs` executes every runnable lesson through its browser controls using the real release kit, fails if any command asks for a passphrase, and checks the resulting receipts. It preserves the real processing/retract windows (about seven minutes of waiting) and includes the optional wallet and transaction inspections. CI saves screenshots and the terminal transcript. These checks do not provision a Codespace or test GitHub's creation/auto-opening UI.

To run the browser checks locally after installing dependencies:

```bash
cd tutorial
npx playwright install --with-deps chromium
npm run test:browser
node test-demo.cjs
```

The full-demo test installs the kit in an isolated temporary home and removes it after the run. It needs Ubuntu 24.04 x86_64 and internet access to download the pinned release.

## Boundaries

- The HTTP server binds to loopback, and Codespaces forwards the private port. It validates hosts and WebSocket origins and requires a per-process connection token.
- It is deliberately one tmux session and one active browser tab per tutorial server. The Codespaces access control is the authentication boundary; never make this port public.
- Reconnecting replays a bounded terminal history. It does not restart Bash. Stopping the server or Codespace loses live shell variables and processes.
- A Run button means the command was sent, not that its result passed an assessment. Prompt readiness is tracked per shell through private temporary state files, including when tmux switches windows; it is a usability mechanism, not a security boundary.
- No credentials are needed for the demo. A terminal has the same access as the Codespace user; avoid adding unrelated secrets to a tutorial environment.
