# Tasks: Pay-by-name on the stepper

**Input**: `specs/026-pay-by-name-on-the-stepper/spec.md` (P1 story + acceptance), `plan.md`
**Prerequisites**: #22 and #23 merged (attribute spelling, stepper shape, `tutorial-stepper v0.4.0` pin); `demos/pay-by-name/` owned by this issue

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Spec (record first)

- [ ] T001 [US1] Write `specs/026-pay-by-name-on-the-stepper/{spec,plan,tasks}.md` from the `.specify` templates; commit on `feat/26-pay-by-name` (no code yet)

## Phase 2: Failing test first (TDD)

- [ ] T002 [US1] RED: `tutorial-stepper check demos/pay-by-name` fails with "cannot read tutorial.toml" (no index yet); journal the failure, keep the output as RED evidence
- [ ] T003 [US1] RED: shortest-path `play --auto --run-setup` refused before any shell (no index / missing setup); journal the failure

## Phase 3: Index + set-up + visible shell setup

- [ ] T004 [US1] Add `demos/pay-by-name/tutorial.toml` (shell, setup, all 12 pages, 5 windows, needs incl. `sink-tools`, no settings/paths); `check` goes GREEN on the index shape (blocks may still fail)
- [ ] T005 [US1] Add `demos/pay-by-name/setup.sh` + `demos/pay-by-name/play/stepper.sh` (folders, helpers + `settings()`/`outputs_at()`, `path.env`, window words as no-ops); GREEN: fresh `--run` folder has the layout `check-run.sh` expects
- [ ] T006 [US1] First page `s01-setup.md` loads each window's shell visibly (5 command blocks sourcing the stepper file); `killercoda.js` skips exactly these bodies; GREEN: one-path smoke run reaches the devnet wait

## Phase 4: Attributes + generator + flake + CI + docs

- [ ] T007 [US1] Annotate all 64 fences in `demos/pay-by-name/s*.md` per spec FR-001–FR-004 (`window=` everywhere, `status=1` only on the refused `old.bundle` move, no `mode`); change fence lines only
- [ ] T008 [US1] `demos/pay-by-name/killercoda.js`: parse `{ window }`, delete the `PERSON`/`skip` branch, skip the stepper-setup loads; `mode=show` plain, `mode=observe`/command `{{exec}}`; GREEN: `node demos/pay-by-name/killercoda.js .` + `git diff --exit-code killercoda/` clean
- [ ] T009 [US1] Expose `sink-tools` in the dev shell (wrapper over `payByName.tools` + `nodejs-slim`); GREEN: `nix develop --command bash -c 'command -v sink-tools && sink-tools --help'` prints the usage
- [ ] T010 [US1] CI job `runbook-pay-by-name` (nixos, parallel to `runbook`): `check`, then `play --auto --run-setup`, then `check-run.sh` on the run folder; `pay-by-name` and `terminal` jobs untouched
- [ ] T011 [US1] Docs ride with the behaviour (`README.md` stepper wording for the story, `justfile` `test-pay-by-name` recipe); GREEN: docs build passes

## Phase 5: Green + verification

- [ ] T012 [US1] GREEN: `tutorial-stepper check demos/pay-by-name` passes from the pinned input
- [ ] T013 [US1] `play --auto --run-setup --transcript` passes in the dev shell + `check-run.sh` passes on the run folder (with the per-block real-vs-declared exit cross-check green)
- [ ] T014 [US1] `node demos/pay-by-name/killercoda.js .` then `git diff --exit-code killercoda/` clean (or each difference explained for `COMPLETE`)
- [ ] T015 [US1] Repository lint (`tools/lint.sh`), `tools/format.sh check` and the documentation build pass; review the full diff, commit bisect-safe steps, journal `COMPLETE done head=<sha> checks=<ci job names>`, wait on channels

## Dependencies & Execution Order

- T001 before everything (record first); committed alone
- T002–T003 before T004 (tests first, REDs watched)
- T004 before T005–T006 (index is the input the runs handle)
- T005, T006, T007 in order (setup → visible env → attributes; disjoint files but sequential runs)
- T008 after T006–T007 (generator rides on the working run); T009 after T004 (binary needed for GREENs, pinned early)
- T010–T011 after T004–T009; T012–T015 last
