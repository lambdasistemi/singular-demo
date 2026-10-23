# Feature Specification: CI plays the demo with tutorial-stepper

**Feature Branch**: `feat/23-ci-on-the-stepper`
**Created**: 2026-10-23
**Status**: Specified
**Input**: Issue 23, "CI plays the demo with tutorial-stepper" (epic 21)

## User Scenarios & Testing

### User Story 1 — A maintainer pushes and CI plays the tested paths (Priority: P1)

As a maintainer of the demo, I push a pull request and observe CI play the demo's tested paths with `tutorial-stepper play --auto`, failing at the first command whose status differs from the one declared, with the transcript kept as evidence.

**Why this priority**: This is the whole issue. The runbook's `awk` extraction and the `record.js` pairing go away; the stepper is the only runner.

**Independent Test**: `tutorial-stepper check demos/demo1` passes; `tutorial-stepper play --auto demos/demo1 --path short --run /tmp/<id>-run --run-setup --transcript /tmp/<id>-transcript` passes inside the development shell (about 5 minutes) and `demos/demo1/play/check-receipts.sh /tmp/<id>-run` passes on its run folder.

**Acceptance Scenarios**:

1. **Given** `demos/demo1`, **When** CI runs the stepper, **Then** the runbook and terminal jobs run the stepper, the extraction in `demos/demo1/test.sh` and the pairing in `demos/demo1/record.js` are deleted, and the receipt checks still pass.
2. **Given** a pull request, **When** CI plays the whole run, **Then** it uses the shortest windows (60 s and 30 s) and stays about 10 minutes.
3. **Given** the step files, **When** the Killercoda scenario is regenerated, **Then** `killercoda/` is byte-identical.

## Requirements

### Functional Requirements

- **FR-001**: `demos/demo1/tutorial.toml` declares the windows `alice` (folder `alice`), `bob` (folder `bob`) and `chain` (folder `.`); the set-up script; the programs needed; and the settings `PROCESS_TIME_MS` and `RETRACT_TIME_MS` with two tested paths: the shortest windows (60000 and 30000) for pull requests and the tutorial's own (180000 and 60000) for `main` and nightly.
- **FR-002**: The set-up script does what `play/prepare.sh` does for the stepper run (window sub-folders for receipts, bundles, witnesses; empty per-person settings files; shell-setup files where the run can source them).
- **FR-003**: What each window's shell needs (`PATH` programs, `blueprint`, `SINGULAR_CONFIG`, `SINGULAR_PASSPHRASE`, helpers `koios_url`, `wait_for_slot`, `wallet_show`) comes from commands visible on the tutorial's first page (one block per window loading the play's shell setup), never from a hidden mechanism.
- **FR-004**: The create step reads the registry's windows from the settings (e.g. `process_ms=${PROCESS_TIME_MS:-180000}; retract_ms=${RETRACT_TIME_MS:-60000}`) while every other consumer keeps working: the Killercoda scenario, the Codespaces tutorial, `kit/demo.sh` and `kit/drive.sh` (until #24), and `short-windows.sh`'s users.
- **FR-005**: Blocks that only look (wallets, the chain's view of a transaction) are observations (`mode=observe`).
- **FR-006**: `tutorial-stepper` is a flake input pinned to release tag `v0.3.1` and its binary is what CI uses.
- **FR-007**: `tutorial-stepper check demos/demo1` passes in CI; the runbook and terminal jobs run the stepper; `test.sh` extraction and `record.js` pairing are deleted; receipt checks still pass.
- **FR-008**: No committed change outside `demos/demo1/` (steps, `tutorial.toml`, set-up script, `play/`, `test.sh`/`record.js` removal, `check-receipts.sh` adaptation), `flake.nix`/`flake.lock`, `.github/workflows/ci.yml`, `tools/`, `docs/`, `killercoda/` (only if the generator forces it, byte-identical otherwise) and `specs/023-ci-on-the-stepper/`. `demos/pay-by-name/` and the kit keep working.
- **FR-009**: Every behaviour ships its documentation in the same commit (tutorial-stepper docs `format.md`/`play.md`/`script.md` are the format reference; this repository's `README.md`/docs ride with the behaviour).

## Success Criteria

- **SC-001**: `tutorial-stepper check demos/demo1` passes from the pinned flake input.
- **SC-002**: The shortest-path unattended run passes in the dev shell (~5 min) and `play/check-receipts.sh` passes on its run folder.
- **SC-003**: `node demos/demo1/killercoda.js .` then `git diff --exit-code killercoda/` reports no difference.
- **SC-004**: Repository lint and the documentation build pass; pull-request CI stays about 10 minutes.

## Assumptions

- tutorial-stepper release `v0.3.1` already has `check`, `script`, `play --auto` with `--run`, `--run-setup`, `--path` and observations; no format change is needed (a format change is a question, not an implementation).
- `demos/demo1/s*.md` windows/statuses from #22 are correct; this issue only reclassifies look-only blocks to `mode=observe` where the pages promise re-runnability.
- The two tested-path names are `short` (60000/30000, pull requests) and `tutorial` (180000/60000, `main`/nightly); CI selects the path by event.
