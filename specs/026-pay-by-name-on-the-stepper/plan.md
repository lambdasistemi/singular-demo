# Implementation Plan: Pay-by-name on the stepper

**Branch**: `feat/26-pay-by-name` | **Date**: 2026-10-23 | **Spec**: `specs/026-pay-by-name-on-the-stepper/spec.md`

## Summary

Annotate all 64 ` ```bash ` fences in `demos/pay-by-name/s*.md` with `{ window=... }` (plus `status=1` on the one refused move), teach `killercoda.js` the braced form while skipping the five new stepper-setup loads so its output stays byte-identical, and give the story a `tutorial.toml` (five windows, no settings), a `setup.sh` and a `play/stepper.sh` so `play --auto` runs it in the dev shell and in a new parallel CI job. Expose `sink-tools` in the dev shell. Delete nothing; `drive.sh` keeps working until #24.

## Technical Context

**Language/Version**: bash + Node.js 22 (existing scripts, no new runtime); tutorial-stepper 0.4.0 binary via flake input (already pinned)
**Primary Dependencies**: `payByName.tools` (flake `pay-by-name-tools`, already built) wrapped as `sink-tools` for the dev shell; no other addition
**Storage**: N/A (Markdown tutorial + `tutorial.toml` + run folders under `/tmp`)
**Testing**: repository gates — `tools/lint.sh` (incl. generate-diff), `tools/format.sh check`, `mkdocs build --strict`, `tutorial-stepper check`, single-path `play --auto --run-setup` + `play/check-run.sh`, `node demos/pay-by-name/killercoda.js .` + `git diff --exit-code killercoda/`
**Target Platform**: `x86_64-linux` (nixos runners for stepper jobs; ubuntu-24.04 jobs unchanged)
**Project Type**: tutorial repository (owned folder `demos/pay-by-name/`; `demos/demo1/` and the kit keep working)
**Performance Goals**: pull-request CI stays about 10 minutes (new stepper job runs parallel to `runbook`)
**Constraints**: `killercoda/pay-by-name-steps` regenerated MUST be byte-identical; every CI job stays a required check (`runs-on: nixos` for the new stepper job); release-please untouched; Conventional Commits, no attribution
**Scale/Scope**: 64 fences in 11 step files (1 status, 0 modes); 1 index file; 1 set-up script; 1 shell-setup file; generator; flake dev shell; 1 new CI job

## Constitution Check

The repository has no `.specify/` constitution of its own; the governing principles are tutorial-stepper constitution v1.0.0 and the brief's settled decisions:

- Principle II (plain CommonMark): only `lang { key=value }` attributes; no syntax invented. No departure.
- Principle III (nothing runs unseen): set-up script shown to the learner and run only with `--run-setup`; shell setup via five visible first-page blocks, never hidden. No departure.
- Principle IV (tutorial brings its environment): `tutorial.toml` declares programs, set-up script; `check` + clean-machine `play --auto` is the proof. Needs carry minimums only where `PROGRAM --version` prints a dotted number (`sink-tools` is presence-only). No departure.
- Principle V (every tutorial is a test): `play --auto` exits non-zero at the first unexpected status and writes a transcript; `check-run.sh` judges the run folder. No departure.
- Principle VIII (observations): no block qualifies (no page promises re-runnability, unlike Demo 1's extras) — zero observations is the correct count, not a gap. No departure.
- Principle IX (settings at the start): no settings and no paths — the story keeps the registry's default windows and has no long waits to shorten, so there is no tested-path axis (the brief's "shortest path, if the story has settings" covers this). No departure.
- Principle XI (record outranks code): spec/plan/tasks first, docs in the same commits as behaviour. No departure.
- Brief decisions honoured as-is: `tutorial.toml` shape, brace-only attributes, nixos required checks, release-please untouched, no attribution.

No complexity-table entry: no principle is departed from.

## Project Structure

```text
specs/026-pay-by-name-on-the-stepper/
├── spec.md
├── plan.md    # this file
└── tasks.md

demos/pay-by-name/
├── tutorial.toml   # shell, setup, all 12 s*.md, 5 windows, needs (singular/open-datum/devnet/jq/curl/sink-tools), no settings
├── setup.sh        # window/shared folders, shell-setup copies, path.env (as demos/demo1/setup.sh)
├── s*.md          # 64 fences annotated (fence lines only) + 5 stepper-setup loads on s01
├── play/
│   └── stepper.sh  # PLAY_RUN, PATH from path.env, SINGULAR_PASSPHRASE, helpers + settings()/outputs_at(), window words as no-ops
├── killercoda.js  # parse { window }, skip stepper-setup loads, PERSON/skip branch deleted
└── check-run.sh   # unchanged (judges the stepper run folder)

flake.nix flake.lock       # sink-tools wrapper into devShells.default (and .dev); lock only if the pin moves
.github/workflows/ci.yml  # + runbook-pay-by-name (nixos, parallel to runbook)
justfile README.md tools/ # local stepper recipe + runner wording ride with the behaviour
```

**Structure Decision**: in-place conversion of `demos/pay-by-name` to a tutorial-stepper directory, mirroring #23's Demo 1 shape minus settings/observations. No new folders, one new CI job name (`runbook-pay-by-name`, listed in `COMPLETE`).

## Design

- **Index**: `shell = "bash"`; `setup = "setup.sh"`; `pages` lists all 12 `s*.md` (`s01-setup` … `s12-limits`) in order; `[[window]]` `carol`→`carol`, `alice`→`alice`, `dave`→`dave`, `bob`→`bob`, `chain`→`.`; each `needs` the six programs (minimums `singular >= 0.16.0`, `open-datum >= 0.16.0` as Demo 1; `devnet`/`jq`/`curl`/`sink-tools` presence-only). No `[[setting]]`, no `[[path]]`.
- **Set-up script**: runs in the run folder after window folders exist. Creates `carol/alice/dave/bob/publish/messages`; copies `../demo1/play/helpers.sh` (koios_url/wallet_show) and `play/stepper.sh` beside a generated `path.env`; resolves the six programs to directories now (`command -v`, deduped, as Demo 1 does). Never needs root, installs nothing.
- **Visible shell setup**: `s01-setup.md` gains one command block per window at the top (`. ../stepper.sh` in the four person windows, `. ./stepper.sh` in `chain`). From then on every command relies only on what those blocks installed. `killercoda.js` recognises exactly these bodies and skips them (Killercoda's windows already source `windows.rc`; the loads are stepper-only — the Demo 1 analogue is its `alice`/`bob` word blocks, which likewise never reach the scenario).
- **One-line-per-command**: keep every block one command per line (scenario test and `kit/drive.sh` send blocks line by line and only know backslash continuations); the devnet wait fails at once when the devnet dies (`kill -0` guard as Demo 1), and a trap stops its process group on shell exit.
- **Statuses**: `status=1` only on the refused `... --to "$alice_addr" --bundle old.bundle` (verified: `tx.mjs` prints `the sink refuses this move:` + `Trace sink-conservation` and `process.exit(1)`). All other 63 blocks carry no `status` (expect 0). The run cross-checks real vs declared per block.
- **Flake**: `sink-tools` as `writeShellScriptBin` wrapping `${payByName.tools}/sink-tools.cjs` with `${pkgs.nodejs-slim}/bin/node`; added to `devShells.default` (and `.dev` if it carries the same tutorial programs). `GUARD_ALLOW` in `kit/guard.sh` already covers `pay-by-name-tools-*`; extend only if the wrapper adds a new derivation name the gate would refuse.
- **CI**: new job `runbook-pay-by-name` (`needs: build-gate`, `runs-on: nixos`, ~15 min timeout): `tutorial-stepper check demos/pay-by-name`, then `nix develop --command tutorial-stepper play --auto demos/pay-by-name --run /tmp/pay-by-name-run --run-setup --transcript /tmp/pay-by-name-transcript.toml`, then `nix develop --command bash demos/pay-by-name/check-run.sh /tmp/pay-by-name-run` (screens variant stays Killercoda-only). Keep `pay-by-name` and `terminal` jobs byte-identical until #24.
- **Killercoda**: `parse` as Demo 1 (brace attributes, `window` required, `mode`/`status` optional); `render` as pay today (goTo insertion on window change) plus: skip the five stepper-setup bodies, render `mode=show` as plain block and `mode=observe`/command as `{{exec}}`. Any other spelling is an error at that fence's line.
- **Docs**: `README.md` pay-by-name row names `tutorial-stepper play --auto` beside `drive.sh pay-by-name`; `justfile` gains `test-pay-by-name` (same shape as `test-demo1` without `--path`). `docs/build.sh` unchanged (still Demo 1's transcript + demo log).

## Verification

From `/code/singular-demo-issue-26`, each journaled as `GATE-PASS`/`GATE-FAIL`:

1. `tutorial-stepper check demos/pay-by-name` (from the pinned flake input, inside the dev shell).
2. `tutorial-stepper play --auto demos/pay-by-name --run /tmp/<id>-run --run-setup --transcript /tmp/<id>-transcript` in the dev shell + `demos/pay-by-name/check-run.sh /tmp/<id>-run`.
3. `node demos/pay-by-name/killercoda.js .` then `git diff --exit-code killercoda/`.
4. `tools/lint.sh`, `tools/format.sh check` and the documentation build (`docs/build.sh` with the Demo 1 logs, or `mkdocs build --strict` after the same change #23 made).
