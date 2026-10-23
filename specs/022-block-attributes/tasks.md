# Tasks: Block attributes for Demo 1

**Input**: `specs/022-block-attributes/spec.md` (P1 story + acceptance), `plan.md`
**Prerequisites**: none (first child of the epic; needs nothing from tutorial-stepper)

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Spec (record first)

- [ ] T001 [US1] Write `specs/022-block-attributes/{spec,plan,tasks}.md` from the `.specify` templates; commit on `feat/22-block-attributes` (no code yet)

## Phase 2: Failing test first (TDD)

- [ ] T002 [US1] Add the strict fence check to `demos/demo1/lint.sh` (every demo1 ` ```bash ` fence carries `window=` in braces; ` ```bash PERSON ` / ` ```bash skip ` word fences still accepted for pay-by-name); run it and watch it fail on the bare fences (RED evidence in the journal)

## Phase 3: Annotate the step files

- [ ] T003 [US1] Annotate all 94 fences in `demos/demo1/s*.md` per spec FR-001–FR-005 (windows, the 19/10 statuses on alone-ending builds/refusals, `mode=show` on the 12 skip blocks, `mode=observe` on s20+s21); change fence lines only

## Phase 4: Consumers + docs config

- [ ] T004 [US1] `demos/demo1/killercoda.js`: parse attributes, window replaces `actorOf`; delete `actorOf` and its regexes; markers/show/exec rendering unchanged
- [ ] T005 [P] [US1] `demos/demo1/test.sh` + `demos/demo1/record.js`: extract commands + observations, exclude `mode=show`; same numbering as today
- [ ] T006 [P] [US1] `demos/demo1/build.js`: parse braced fences; generated pages keep the attributed fences
- [ ] T007 [P] [US1] `mkdocs.yml`: enable `pymdownx.superfences`

## Phase 5: Green + verification

- [ ] T008 [US1] GREEN: `bash tools/generate.sh /tmp/gen-diff && diff -r /tmp/gen-diff/killercoda killercoda` clean; repository lint passes; `tools/format.sh check` passes
- [ ] T009 [US1] Docs: `mkdocs build --strict` passes and attributed blocks render as code blocks
- [ ] T010 [US1] Runbook: `PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000` runbook test passes (~5 min), with the ad-hoc per-block exit-status cross-check green
- [ ] T011 [US1] Review the full diff, commit bisect-safe steps, journal `COMPLETE done head=<sha> checks=<ci job names>`, wait on channels

## Dependencies & Execution Order

- T001 before everything (record first); committed alone
- T002 before T003 (test first, RED watched)
- T003 before T004–T007 (annotation is the input the readers handle)
- T004, T005, T006, T007 in parallel (disjoint files)
- T008 after T003–T007; T009–T010 after T008; T011 last
