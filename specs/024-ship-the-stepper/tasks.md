# Tasks: Ship the stepper in the kit and on Homebrew

**Input**: `specs/024-ship-the-stepper/spec.md` (P1 story + acceptance), `plan.md`
**Prerequisites**: #23 + #26 merged (both tutorials play on the stepper); tutorial-stepper v0.4.1 released

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Spec (record first)

- [ ] T001 [US1] Write `specs/024-ship-the-stepper/{spec,plan,tasks}.md` from `.specify/templates/`; commit on `feat/24-ship-the-stepper` (no code yet)

## Phase 2: Failing tests first (TDD)

- [ ] T002 [US1] RED: `homebrew/test-render.sh` fails (no templates yet); journal the failure as RED evidence
- [ ] T003 [US1] RED: `kit/verify.sh` on the current kit fails the new assertions (`bin/tutorial-stepper` absent, tutorials absent); journal the failure

## Phase 3: Flake pin + kit carries the stepper and the tutorials

- [ ] T004 [US1] Move the `tutorial-stepper` flake input v0.4.0 → v0.4.1 (`--update-input` only); GREEN: dev-shell `tutorial-stepper --version` prints 0.4.1
- [ ] T005 [US1] `kit/build.nix` installs the static `tutorial-stepper-0.4.1-x86_64-linux` as `bin/tutorial-stepper`, hash-checked against `kit/tutorial-stepper.sha256` (the release `SHA256SUMS` line); GREEN: `nix build .#kit` holds the binary with that hash
- [ ] T006 [US1] `kit/build.nix` carries both tutorials under `share/tutorials/`; `kit/README.txt` says `tutorial-stepper play`; raise `kit/revision`; GREEN: unpacked kit plays interactively per README
- [ ] T007 [US1] Delete `kit/drive.sh`, `kit/drive-run.sh`, both `play/drive-rc.sh`; remove every reference (build, verify, CI, README/docs/justfile); GREEN: nothing references the deleted files

## Phase 4: Container test + verify

- [ ] T008 [US1] Add `kit/stepper-run.sh` (clean-Ubuntu `--path short` stepper play + receipt checks, both scenarios); switch the `terminal` CI job to it; GREEN: `TARBALL=… kit/stepper-run.sh` passes for Demo 1
- [ ] T009 [US1] Extend `kit/verify.sh` (binary + version + hash + tutorials + `check` on both + drive.sh absence); GREEN: `nix run .#kit-verify` passes

## Phase 5: Homebrew formulas + release push (no tap writes on PRs)

- [ ] T010 [US1] Add `homebrew/` templates + `render.sh` (real + `--local` modes); GREEN: `homebrew/test-render.sh` passes (deps, urls, shas, play command)
- [ ] T011 [US1] Release workflow `tap` job renders with real urls and pushes to `homebrew-tap` with the org-app token (tags only); GREEN: `actionlint` clean

## Phase 6: macOS proof + docs + green

- [ ] T012 [US1] CI `homebrew` job on `macos-14`: temp local tap from the PR, install `singular-demo`, `brew test`, play Demo 1's shortest path unattended; GREEN by reading (cannot run macOS here; stated in `COMPLETE`)
- [ ] T013 [US1] Docs ride with the behaviour (README + site: kit/`tutorial-stepper play` on Linux, `brew install` + `singular-demo` on macOS; `justfile` recipes); GREEN: docs build passes
- [ ] T014 [US1] GREEN: `nix build .#kit` + `kit/verify.sh` pass; container test receipt checks pass; `actionlint` clean; render test passes
- [ ] T015 [US1] Review the full diff, commit bisect-safe steps with docs in the same commits, journal `COMPLETE done head=<sha> checks=<ci job names>` (naming the new jobs), wait on channels

## Dependencies & Execution Order

- T001 before everything (record first); committed alone
- T002–T003 before T004/T010 (tests first, REDs watched)
- T004 before T005 (binary comes from the moved input)
- T005–T007 in order (binary → tutorials → deletions; disjoint files, sequential builds)
- T008 after T006 (test plays the carried tutorials); T009 after T005–T007 (verify judges the finished kit)
- T010 before T011–T012 (templates feed release + CI); T013 with each behaviour commit
- T014–T015 last
