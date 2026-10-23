# Tasks: CI plays the demo with tutorial-stepper

**Input**: `specs/023-ci-on-the-stepper/spec.md` (P1 story + acceptance), `plan.md`
**Prerequisites**: none beyond #22 and tutorial-stepper 0.3.1 (already released)

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Spec (record first)

- [ ] T001 [US1] Write `specs/023-ci-on-the-stepper/{spec,plan,tasks}.md` from the tutorial-stepper templates; commit on `feat/23-ci-on-the-stepper` (no code yet)

## Phase 2: Failing test first (TDD)

- [ ] T002 [US1] RED: `tutorial-stepper check demos/demo1` fails with "cannot read tutorial.toml" (no index yet); journal the failure, keep the output as the RED evidence
- [ ] T003 [US1] RED: shortest-path `play --auto --path short` refused before any shell (no index / missing setup); journal the failure

## Phase 3: Index + set-up + visible shell setup

- [ ] T004 [US1] Add `demos/demo1/tutorial.toml` (shell, setup, all 25 pages, windows alice/bob/chain, needs, settings + paths short/tutorial); `check` goes GREEN on the index shape (blocks may still fail)
- [ ] T005 [US1] Add `demos/demo1/setup.sh` (folders, empty per-person jsons, shell-setup copies); GREEN: fresh `--run` folder has the layout `check-receipts.sh` expects
- [ ] T006 [US1] First page loads each window's shell visibly (one command block per window sourcing the play's shell setup; PATH/blueprint/SINGULAR_CONFIG/SINGULAR_PASSPHRASE/helpers from those blocks); GREEN: a one-path smoke run reaches the devnet wait
- [ ] T007 [US1] Create step reads windows from settings (`process_ms=${PROCESS_TIME_MS:-180000}; retract_ms=${RETRACT_TIME_MS:-60000}`); adapt or retire `play/short-windows.sh` with its users; GREEN: short and tutorial values each land in `receipts/01-create.json` rules

## Phase 4: Observations + flake + CI + deletions + docs

- [ ] T008 [US1] Reclassify look-only blocks to `mode=observe` (s20 all, s21 re-runnable); GREEN: `check` counts them as observations, `script` still prints them, `play` runs them where they appear and at the end
- [ ] T009 [US1] Pin `tutorial-stepper v0.3.1` as a flake input; expose its binary in the dev shells; GREEN: `nix run .#tutorial-stepper -- --version` (or dev-shell `tutorial-stepper --version`) prints 0.3.1
- [ ] T010 [US1] CI runbook + terminal jobs run the stepper (`check`, then `play --auto --path short` on PR / `--path tutorial` on main/nightly, then `play/check-receipts.sh` on the run folder); docs in the same commits
- [ ] T011 [US1] Delete `demos/demo1/test.sh` extraction and `demos/demo1/record.js` pairing; adapt `play/check-receipts.sh` to the stepper run folder and `docs/build.sh` off `record.js`; GREEN: nothing references the deleted files
- [ ] T012 [US1] Docs ride with the behaviour (README/docs pages for the stepper run, transcript evidence, settings/paths); GREEN: docs build passes

## Phase 5: Green + verification

- [ ] T013 [US1] GREEN: `tutorial-stepper check demos/demo1` passes from the pinned input
- [ ] T014 [US1] `play --auto --path short --run /tmp/<id>-run --run-setup --transcript /tmp/<id>-transcript` passes in the dev shell (~5 min) + `play/check-receipts.sh` passes on the run folder
- [ ] T015 [US1] `node demos/demo1/killercoda.js .` then `git diff --exit-code killercoda/` clean (or each difference explained for COMPLETE)
- [ ] T016 [US1] Repository lint (`tools/lint.sh`) and docs build pass; review the full diff, commit bisect-safe steps, journal `COMPLETE done head=<sha> checks=<ci job names>`, wait on channels

## Dependencies & Execution Order

- T001 before everything (record first); committed alone
- T002–T003 before T004 (tests first, REDs watched)
- T004 before T005–T007 (index is the input the runs handle)
- T005, T006, T007 in order (setup → visible env → settings wiring; disjoint files but sequential runs)
- T008 after T006 (observations ride on the working run); T009 after T004 (binary needed for GREENs, pinned early)
- T010–T012 after T004–T009; T013–T016 last
