# Feature Specification: Each block's window and status in the step files

**Feature Branch**: `feat/22-block-attributes`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Issue 22, "Write each block's window and status in the step files" (epic 21)

## User Scenarios & Testing

### User Story 1 — A maintainer reads window and status on each command block (Priority: P1)

As a maintainer of the demo, I read a step file and observe on each command block the window it runs in and the status it ends with when that is not 0, and the Killercoda scenario generated from the step files is unchanged.

**Why this priority**: This is the whole issue. Nothing about a block is guessed from its command text afterwards; the window and the expected status are written on the block, in the `lang { key=value }` form the tutorial-stepper format specifies.

**Independent Test**: Every ` ```bash ` fence in `demos/demo1/s*.md` opens with attributes in braces carrying `window=alice|bob|chain` (plus `status=N` exactly where the block ends non-zero, `mode=show` exactly where it is shown only, `mode=observe` exactly where it may be re-run any time); `node demos/demo1/killercoda.js .` followed by `git diff --exit-code killercoda/` reports no difference.

**Acceptance Scenarios**:

1. **Given** any command block of the tutorial, **When** a maintainer reads its fence, **Then** the fence names the window (`alice`, `bob` or `chain`) and, only when the block ends with a non-zero status, that status.
2. **Given** a block the tutorial shows but never runs, **When** a maintainer reads its fence, **Then** the fence carries `mode=show` instead of the old `skip` word.
3. **Given** a block the pages say may be run again at any time, **When** a maintainer reads its fence, **Then** the fence carries `mode=observe`.
4. **Given** the annotated step files, **When** the Killercoda scenario is regenerated, **Then** the `killercoda/` tree is byte-identical to the one committed before the change.

## Requirements

### Functional Requirements

- **FR-001**: Every ` ```bash ` fence in `demos/demo1/s*.md` MUST open as ` ```bash { window=W ... } ` with `W` one of `alice`, `bob`, `chain`. No bare ` ```bash ` fence and no ` ```bash skip ` fence remains in those files.
- **FR-002**: A block whose body ends with a non-zero exit MUST carry `status=N` with that exit. The status is the whole fence body's exit (its last command): the bundle build that stands alone in its block (exit 19) and the too-early reclaim that stands alone (exit 10). A bundle build or refusal that shares its block with a following `jq` ends at 0 and MUST NOT carry `status`.
- **FR-003**: Every current ` ```bash skip ` block MUST become ` ```bash { window=W mode=show } ` with the code lines untouched (s00a ×2, s00b ×1, s04 recovery ×3, s09 recovery ×3, s22 ×3).
- **FR-004**: The blocks the pages say to run again whenever liked MUST carry `mode=observe`: all of `s20-extra-wallets.md` (3 blocks) and the five re-runnable blocks of `s21-extra-transactions.md` (its person switch stays a command). Every other runnable block is a command (no `mode`).
- **FR-005**: Window rule. A block runs in the window of the person whose vault, settings file or address it uses; a neutral read runs in the page's current window; only the devnet's own lifecycle (start it, wait for its settings line, stop it) runs in `chain`. A block that is exactly the word `alice` or `bob` (the single-terminal person switch) carries the window it names. Page currents: s01 alice; s02 bob after its switch; s03 alice; s04 bob; s05–s08 alice; s09 bob; s10 alice; s11 alice then bob; s12 bob; s13–s15 alice; s16 bob then alice; s20 alice; s21 bob.
- **FR-006**: `demos/demo1/killercoda.js` MUST read the window from the attributes; `actorOf` and its command-text regular expressions MUST be deleted. A block that is exactly a window name stays the person switch (with its `**Now X.**` caption rule); `mode=show` renders as a plain block exactly as `skip` did; `mode=observe` renders as a click-to-run block exactly as a command did.
- **FR-007**: Every consumer of the step files MUST keep working with the attributes: the block extraction in `test.sh`, `record.js`, `build.js`, the block markers `checks.sh` reads, `lint.sh` (which also runs over `demos/pay-by-name/s*.md` and MUST keep accepting that story's ` ```bash PERSON ` / ` ```bash skip ` fences), the generator, and the documentation site.
- **FR-008**: `mkdocs.yml` MUST enable `pymdownx.superfences`, so attributed blocks still render as code blocks. Generated pages (`record.js`, `build.js`) MUST keep the attributed fences instead of stripping them.
- **FR-009**: No committed change outside `demos/demo1/s*.md`, `demos/demo1/killercoda.js`, `demos/demo1/test.sh`, `demos/demo1/record.js`, `demos/demo1/build.js`, `demos/demo1/lint.sh`, `mkdocs.yml` and `specs/022-block-attributes/`. `demos/pay-by-name/` is touched only if a shared program forces it, and stays working.

### Key Entities

- **Command block**: an attributed fence with no `mode`; runs where it stands.
- **Show block**: `mode=show`; shown only, never run, never counted.
- **Observation block**: `mode=observe`; runs where it stands and may be re-run any time.
- **Person switch**: a command block whose code is exactly `alice` or `bob`; sets `SINGULAR_CONFIG` in the single-terminal run and moves the learner in Killercoda.

## Success Criteria

- **SC-001**: `node demos/demo1/killercoda.js .` then `git diff --exit-code killercoda/` — no difference.
- **SC-002**: The repository lint entry point passes.
- **SC-003**: The runbook test passes with the shortest windows (about 5 minutes).
- **SC-004**: The documentation site builds strictly with the attributed blocks rendered as code blocks.

## Assumptions

- The exact non-zero statuses (19 for bundle builds, 10 for too-early refusals) are taken from the tutorial's own statements and the receipt outcomes; the verification run cross-checks every block's real exit against its fence.
- Statuses describe whole blocks (the shell's exit for the fence body); a bundle build that shares its block with a following `jq` ends at 0 and carries no `status`.
- `demos/pay-by-name/` keeps its current fence style; issue 26 converts it.
