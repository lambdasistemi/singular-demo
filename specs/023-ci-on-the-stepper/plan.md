# Implementation Plan: CI plays the demo with tutorial-stepper

**Branch**: `feat/23-ci-on-the-stepper` | **Date**: 2026-10-23 | **Spec**: `specs/023-ci-on-the-stepper/spec.md`

## Summary

Give `demos/demo1` a `tutorial.toml` (windows alice/bob/chain, set-up script, programs, settings `PROCESS_TIME_MS`/`RETRACT_TIME_MS` with paths `short` and `tutorial`), make the first page visibly load each window's shell setup, make the create step read the windows from settings, reclassify look-only blocks to `mode=observe`, pin `tutorial-stepper v0.3.1` as a flake input, and switch the runbook/terminal CI jobs to `play --auto`. Delete the `test.sh` extraction and the `record.js` pairing; keep receipt checks and the Killercoda output byte-identical.

## Technical Context

**Language/Version**: bash + Node.js 22 (existing scripts, no new runtime); tutorial-stepper 0.3.1 binary via flake input
**Primary Dependencies**: `tutorial-stepper v0.3.1` (flake input `github:lambdasistemi/tutorial-stepper/v0.3.1`); no other addition
**Storage**: N/A (Markdown tutorial + `tutorial.toml` + run folders under `/tmp`)
**Testing**: repository gates — `tools/lint.sh` (incl. generate-diff), `tools/format.sh check`, `mkdocs build --strict`, `tutorial-stepper check`, shortest-path `play --auto` + `play/check-receipts.sh`, `node demos/demo1/killercoda.js .` + `git diff --exit-code killercoda/`
**Target Platform**: `x86_64-linux` (nixos runners for stepper jobs; ubuntu-24.04 jobs unchanged)
**Project Type**: tutorial repository (owned folder `demos/demo1/`; `demos/pay-by-name/` and the kit keep working)
**Performance Goals**: pull-request CI stays about 10 minutes (`--path short`, 60000/30000)
**Constraints**: every CI job stays a required check (`runs-on: nixos` for stepper jobs); no job added/renamed without listing it in `COMPLETE`; release-please untouched; Conventional Commits, no attribution
**Scale/Scope**: 25 step pages; 1 index file; 1 set-up script; ~94 fences (only look-only blocks change mode); flake + CI workflow; deletion of 2 runners

## Constitution Check

The repository has no `.specify/` constitution; the governing principles are tutorial-stepper constitution v1.0.0 and the brief's settled decisions:

- Principle II (plain CommonMark): only `lang { key=value }` attributes; no syntax invented. No departure.
- Principle III (nothing runs unseen): set-up script shown to the learner and run only with `--run-setup`; shell setup via visible first-page blocks, never hidden. No departure.
- Principle IV (tutorial brings its environment): `tutorial.toml` declares programs, set-up script, settings; `check` + clean-machine `play --auto` is the proof. No departure.
- Principle V (every tutorial is a test): `play --auto` exits non-zero at the first unexpected status and writes a transcript; receipt checks judge the run folder. No departure.
- Principle VIII (observations): look-only blocks are `mode=observe`, run where they appear and again at the end. No departure.
- Principle IX (settings at the start): two settings, two tested paths, `.env` before the first page, `if` unused here (all blocks shared). No departure.
- Principle XI (record outranks code): spec/plan/tasks first, docs in the same commits as behaviour. No departure.
- Brief decisions honoured as-is: `tutorial.toml` shape, brace-only attributes, nixos required checks, release-please untouched, no attribution.

No complexity-table entry: no principle is departed from.

## Project Structure

```text
specs/023-ci-on-the-stepper/
├── spec.md
├── plan.md
└── tasks.md

demos/demo1/
├── tutorial.toml        # windows alice/bob/chain, setup, needs, settings, paths short/tutorial
├── setup.sh             # what prepare.sh does for the stepper run (folders, empty jsons, shell-setup copies)
├── s00*.md s01-create.md s20-extra-wallets.md s21-extra-transactions.md  # visible shell-setup blocks; create reads settings; look-only -> mode=observe
├── play/
│   ├── check-receipts.sh  # judges a stepper run folder (alice/ bob/ at top level)
│   ├── short-windows.sh   # adapted or retired with its users (create step no longer needs rewriting)
│   └── prepare.sh windows.sh windows.rc helpers.sh  # kept for Killercoda/Codespaces/kit until #24
├── test.sh record.js     # DELETED (extraction + pairing gone)
└── killercoda.js         # unchanged output (byte-identical killercoda/)

flake.nix flake.lock      # + tutorial-stepper v0.3.1 input, binary on PATH in dev shells / CI
.github/workflows/ci.yml # runbook + terminal jobs run the stepper (short on PR, tutorial on main/nightly)
tools/ docs/ README.md    # lint/docs ride with the behaviour
```

**Structure Decision**: in-place conversion of `demos/demo1` to a tutorial-stepper directory. No new folders, no new CI job names (runbook/terminal jobs change commands, not names; any added/renamed job is listed in `COMPLETE`).

## Design

- **Index**: `shell = "bash"`; `setup = "setup.sh"`; `pages` lists all 25 `s*.md` in order; `[[window]]` alice→`alice`, bob→`bob`, chain→`.`, each with `needs = ["singular", "open-datum", "devnet", "jq", "curl"]` (presence only, no minimums: `*_--version` dotted-number parsing is not relied on); `[[setting]]` `PROCESS_TIME_MS` default `180000` values `["180000","60000"]`, `RETRACT_TIME_MS` default `60000` values `["60000","30000"]`; `[[path]]` `short = {PROCESS_TIME_MS="60000",RETRACT_TIME_MS="30000"}`, `tutorial = {PROCESS_TIME_MS="180000",RETRACT_TIME_MS="60000"}`.
- **Set-up script**: runs in the run folder after window folders exist. Creates `alice/{receipts,bundles,witnesses}`, `bob/{receipts,bundles,witnesses}`; writes empty `alice/alice.json`, `bob/bob.json` when missing; copies `play/helpers.sh` (+ a generated `shell-setup.sh` exporting `PLAY_RUN`, `blueprint` from the caller env) where the first page can source it. Never needs root, installs nothing.
- **Visible shell setup**: the first runnable page gains one command block per window that loads the play's shell setup (e.g. alice/bob blocks source the copied setup, export `SINGULAR_CONFIG=$PWD/<person>.json`, `SINGULAR_PASSPHRASE=demo`, define `alice()/bob()/chain()` words; chain block sources helpers). From then on every command relies only on what those blocks installed. If this cannot work without a stepper format change, ask instead of changing the format.
- **Create step**: `process_ms=${PROCESS_TIME_MS:-180000}; retract_ms=${RETRACT_TIME_MS:-60000}` so the stepper (`.env` exports), `test.sh`-era single-shell runs, `kit/demo.sh`, `kit/drive.sh`, the Killercoda scenario and the Codespaces tutorial all read the same variables. `short-windows.sh` is adapted to the new line or retired with its last user, whichever keeps every consumer green.
- **Observations**: all of `s20-extra-wallets.md` (3 blocks) and the re-runnable `s21` blocks stay `mode=observe`; any further block the pages say to run again whenever liked becomes `mode=observe`; everything else stays a command. Person-switch lines (`alice`/`bob`) stay commands.
- **Flake**: `inputs.tutorial-stepper.url = "github:lambdasistemi/tutorial-stepper/v0.3.1"`; expose its `packages.x86_64-linux.tutorial-stepper` on the dev shells' `PATH` (and as `packages`/`apps` for CI's `nix run`). `flake.lock` updated with `--update-input tutorial-stepper` only.
- **CI**: runbook job runs `tutorial-stepper check demos/demo1` then `play --auto demos/demo1 --path short --run <dir> --run-setup --transcript <file>` on PRs (about 5 min) and `--path tutorial` on `main`/nightly, then `play/check-receipts.sh <dir>`; terminal jobs run the same stepper command where they ran `drive.sh` for Demo 1 (pay-by-name `drive.sh` untouched until #24). Receipt-check script reads the stepper run folder layout (`<run>/alice`, `<run>/bob`, `<run>/registry.address`).
- **Deletions**: `demos/demo1/test.sh` (awk extraction + single-shell run + `checks.sh` pairing) and `demos/demo1/record.js` (log pairing) go away; `checks.sh` stays only if the Killercoda/scenario tests still source it, otherwise goes with them. `docs/build.sh` stops calling `record.js` for Demo 1 and keeps the published run page from the stepper transcript or the kept logs.
- **Killercoda**: `killercoda.js` output stays byte-identical; any unavoidable difference is explained in `COMPLETE`, not committed silently.

## Verification

From `/code/singular-demo-issue-23`, each journaled as `GATE-PASS`/`GATE-FAIL`:

1. `tutorial-stepper check demos/demo1` (from the pinned flake input).
2. `tutorial-stepper play --auto demos/demo1 --path short --run /tmp/<id>-run --run-setup --transcript /tmp/<id>-transcript` in the dev shell (~5 min) + `demos/demo1/play/check-receipts.sh /tmp/<id>-run`.
3. `node demos/demo1/killercoda.js .` then `git diff --exit-code killercoda/`.
4. Repository lint (`tools/lint.sh`) and documentation build.
