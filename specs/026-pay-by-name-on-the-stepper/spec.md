# Feature Specification: Pay-by-name on the stepper

**Feature Branch**: `feat/26-pay-by-name`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Issue 26, "The pay-by-name story plays on tutorial-stepper" (epic 21, after #22 and #23)

## User Scenarios & Testing

### User Story 1 — A maintainer reads window and status on each pay-by-name block (Priority: P1)

As a maintainer of the demo, I read the pay-by-name step files and observe on each command block the window it runs in (carol, alice, dave, bob or chain) and its expected status, and CI plays the story with `tutorial-stepper play --auto`.

**Why this priority**: This is the whole issue. Nothing about a block is guessed from its command text afterwards; the window and the expected status are written on the block, in the `lang { key=value }` form the tutorial-stepper format specifies. `kit/drive.sh` keeps playing the story until #24; the stepper is the second runner that must agree with it.

**Independent Test**: Every ` ```bash ` fence in `demos/pay-by-name/s*.md` opens with attributes in braces carrying `window=carol|alice|dave|bob|chain` (plus `status=1` exactly where the refused move ends non-zero); `node demos/pay-by-name/killercoda.js .` followed by `git diff --exit-code killercoda/` reports no difference; `tutorial-stepper check demos/pay-by-name` passes.

**Acceptance Scenarios**:

1. **Given** any command block of the pay-by-name story, **When** a maintainer reads its fence, **Then** the fence names the window (`carol`, `alice`, `dave`, `bob` or `chain`) and, only where the block ends non-zero, that status.
2. **Given** the annotated step files, **When** the Killercoda scenario is regenerated, **Then** the `killercoda/pay-by-name-steps` tree is byte-identical to the one committed before the change.
3. **Given** `demos/pay-by-name/tutorial.toml`, **When** CI runs `tutorial-stepper check` and `play --auto --run-setup`, **Then** the whole story plays unattended against a fresh devnet and the receipts/screens checks pass on its run folder.
4. **Given** a pull request, **When** CI plays both tutorials, **Then** the wall time stays about 10 minutes.

## Requirements

### Functional Requirements

- **FR-001**: Every ` ```bash ` fence in `demos/pay-by-name/s*.md` MUST open as ` ```bash { window=W ... } ` with `W` one of `carol`, `alice`, `dave`, `bob`, `chain`. No bare ` ```bash ` fence and no ` ```bash PERSON ` / ` ```bash skip ` fence remains in those files. Change fence lines only; code lines untouched. 64 blocks in 11 files (`s01`–`s11`; `s12` has none).
- **FR-002**: Exactly one block carries a status: `s11-rotate.md`'s refused move (`sink-tools move ... --to "$alice_addr" --bundle old.bundle`) MUST carry `status=1` (the builder runs the sink script first and exits 1 with `the sink refuses this move: ... Trace sink-conservation`). Every other block ends at 0 and MUST NOT carry `status`. The verification run cross-checks every block's real exit against its fence.
- **FR-003**: No `mode` anywhere in the story. Unlike Demo 1 (`s20`/`s21` extras), no pay-by-name page promises "run this again whenever you like"; every read (`jq`, `cat`, `wallet_show`, `outputs_at`, `describe`, `check-registry`) is a step of the story, not a re-runnable observation. No `mode=show` block exists today (`skip` was never used here). All 64 blocks are commands.
- **FR-004**: Window rule (same as #22, five windows). A block runs in the window of the person whose vault, settings file or address it uses; a neutral read runs in the page's current window; only the devnet's own lifecycle (start it, wait for its settings line) runs in `chain`. The existing `PERSON` labels already satisfy this (each file's blocks name its person, `s01` names all five, `s10` names alice then dave); the change is spelling only, no block moves windows.
- **FR-005**: `demos/pay-by-name/killercoda.js` MUST read the window from the attributes; the `PERSON`/`skip` branch and its error text MUST go away. `mode=show` renders as a plain block, `mode=observe` as a click-to-run block (as Demo 1 does); `status` is ignored (Killercoda types the block regardless). The story has no `alice`-alone person-switch block, so no `markWords` logic: window moves stay the `goTo` insertions the generator already writes. Output byte-identical.
- **FR-006**: `demos/pay-by-name/tutorial.toml` declares `shell = "bash"`, `setup = "setup.sh"`, `pages` (all 12 `s*.md` in order), five `[[window]]` (`carol`→`carol`, `alice`→`alice`, `dave`→`dave`, `bob`→`bob`, `chain`→`.`) each with `needs` (presence, `singular`/`open-datum` with `>= 0.16.0` as Demo 1; plus `sink-tools`, `devnet`, `jq`, `curl`). No `[[setting]]` and no `[[path]]`: the registry keeps its default ten-minute windows and the story has no long waits to shorten (why this differs from Demo 1, which needs `short`/`tutorial`). Single path; `play --auto` plays it once.
- **FR-007**: `demos/pay-by-name/setup.sh` (new) does for the stepper run what `play/prepare.sh` does for the Killercoda run: window folders `carol/alice/dave/bob`, shared `publish/messages`, copies of the shell setup, and `path.env` resolving the programs of FR-006 to directories now (lesson of #23: no window depends on inherited `PATH`). New `demos/pay-by-name/play/stepper.sh` sets what every window's shell needs (`PLAY_RUN`, `PATH` from `path.env`, `SINGULAR_PASSPHRASE=demo`, helpers `koios_url`/`wallet_show` from Demo 1's `helpers.sh`, pay-by-name `settings()`/`outputs_at()` from `windows.rc` without its `tmux select-window` words, which become no-ops: the stepper already switches windows).
- **FR-008**: The first page (`s01-setup.md`) loads the shell setup visibly, one command block per window sourcing the stepper file (`carol`/`alice`/`dave`/`bob`: `. ../stepper.sh`; `chain`: `. ./stepper.sh`), before any vault is made (lesson of #23). Why this differs from Demo 1: Demo 1's first stepper page (`s00b`) is not a Killercoda step (its setup page is hardcoded), while `s01-setup.md` IS a Killercoda step — so `killercoda.js` MUST skip exactly these five sourcing blocks (body `. ../stepper.sh` / `. ./stepper.sh`), keeping its output byte-identical. Killercoda's windows already have their env from `windows.rc`; the stepper loads are stepper-only, as Demo 1's `alice`/`bob` word blocks are terminal-only.
- **FR-009**: `tutorial-stepper` is already pinned (`v0.4.0`); expose the pay-by-name tools in the dev shell (`sink-tools` wrapper running the flake's `payByName.tools` with its Node.js) so `needs` resolves and `play --auto` runs in `nix develop` the way CI does. `flake.lock` updated with `--update-input` only if the pin moves.
- **FR-010**: CI plays the story with the stepper on `nixos` (new job `runbook-pay-by-name`, parallel to `runbook`, same `nix develop --command tutorial-stepper play --auto demos/pay-by-name --run ... --run-setup --transcript ...` + `demos/pay-by-name/check-run.sh` on the run folder). The existing `pay-by-name` (Killercoda scenario + controls) and `terminal` (`drive.sh pay-by-name`) jobs stay untouched until #24. No other job added or renamed.
- **FR-011**: Every behaviour ships its docs in the same commit: `README.md` names the stepper as the story's runner beside `drive.sh` (as #23 did for Demo 1); `justfile` gains the local stepper recipe. No new docs site page (the story itself is unchanged; the run evidence is the transcript + `check-run.sh`).
- **FR-012**: No committed change outside `demos/pay-by-name/` (`s*.md`, `tutorial.toml`, `setup.sh`, `play/stepper.sh`, `killercoda.js`), `flake.nix`/`flake.lock`, `.github/workflows/ci.yml`, `tools/`, `justfile`, `README.md`, `killercoda/` (only if the generator forces it, byte-identical otherwise) and `specs/026-pay-by-name-on-the-stepper/`. `demos/demo1/`, the kit and `drive.sh` keep working.

## Success Criteria

- **SC-001**: `tutorial-stepper check demos/pay-by-name` passes from the pinned flake input.
- **SC-002**: The shortest-path (here: the only path) unattended run passes in the dev shell and `demos/pay-by-name/check-run.sh` passes on its run folder.
- **SC-003**: `node demos/pay-by-name/killercoda.js .` then `git diff --exit-code killercoda/` reports no difference.
- **SC-004**: Repository lint (`tools/lint.sh`), `tools/format.sh check` and the documentation build pass; pull-request CI stays about 10 minutes.

## Assumptions

- The refused move's exit (1) is taken from `offchain/tx.mjs` (`process.exit(1)` after `the sink refuses this move`); the verification run cross-checks every block's real exit against its fence, as #22 did for Demo 1.
- `sink-tools --version` prints no dotted number, so its `needs` entry carries no minimum (presence only); the dev-shell wrapper supplies its Node.js by absolute path.
- `s12-limits.md` stays text-only (no blocks), as today.
