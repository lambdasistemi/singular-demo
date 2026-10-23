# Implementation Plan: Block attributes for Demo 1

**Branch**: `feat/22-block-attributes` | **Date**: 2026-10-23 | **Spec**: `specs/022-block-attributes/spec.md`

## Summary

Annotate all 94 ` ```bash ` fences in `demos/demo1/s*.md` with `{ window=..., status=..., mode=... }` per the spec, and teach the five fence readers (`test.sh`, `record.js`, `build.js`, `killercoda.js`, `lint.sh`) the braced form while keeping every output byte-identical. No new dependency, no new CI job.

## Technical Context

**Language/Version**: bash + Node.js 22 (existing scripts, no new runtime)
**Primary Dependencies**: none added; `mkdocs-material` already bundles `pymdownx.superfences`
**Storage**: N/A (Markdown files and generated trees)
**Testing**: the repository's own gates — `tools/lint.sh` (incl. generate-diff), `tools/format.sh check`, `mkdocs build --strict`, `demos/demo1/test.sh`
**Target Platform**: `x86_64-linux` (unchanged)
**Project Type**: tutorial repository (single demo folder owned: `demos/demo1/`)
**Performance Goals**: PR CI stays about 10 minutes; the runbook test runs with `PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000`
**Constraints**: `killercoda/` regenerated MUST be byte-identical; `demos/pay-by-name/` MUST keep working; Conventional Commits, no attribution
**Scale/Scope**: 94 fences in 22 step files; 5 readers + `mkdocs.yml`

## Constitution Check

The repository has no `.specify/` constitution of its own; the governing format decisions come from `tutorial-stepper` (constitution v1.0.0) and the brief:

- Principle II (The Source Is Plain CommonMark): the `lang { key=value }` spelling is adopted exactly; no syntax is invented. No departure.
- Principle XI (The Record Outranks the Code): spec, plan and tasks land before any code, in the first commit; the mkdocs change rides with the behaviour commit. No departure.
- Brief decisions honoured as-is: `tutorial.toml` (not this issue), braces-only attributes, `mode=show`/`mode=observe` meanings, bare fence = ordinary block (for readers: bare is still tolerated, but the lint gate forbids it in `demos/demo1/`), NixOS runners with unchanged job names, release-please untouched.

No complexity-table entry: no principle is departed from.

## Project Structure

```text
specs/022-block-attributes/
├── spec.md    # this feature's spec
├── plan.md    # this file
└── tasks.md   # ordered steps

demos/demo1/
├── s*.md          # 94 fences annotated (only fence lines change)
├── killercoda.js  # parse { window }, delete actorOf + regexes
├── test.sh        # extract commands + observations, skip show
├── record.js      # same block set, keep attributed fences
├── build.js       # parse braced fences, keep attributed fences
└── lint.sh        # + strict window check (demo1 braces; pay-by-name PERSON/skip still ok)

mkdocs.yml         # + pymdownx.superfences
```

**Structure Decision**: in-place annotation (no new folders, no new tools). The permanent regression test is a new step inside the existing `demos/demo1/lint.sh` (same CI `lint` job, no job added or renamed).

## Design: fence parsing (one rule, five readers)

Open fence: ` ```bash ` optionally followed by ` { key=value ... } `. Keys `window` (required by the lint gate for demo1), `status` (digits), `mode` (`show`|`observe`). A ` ```bash PERSON ` / ` ```bash skip ` word form is accepted only for the pay-by-name files the shared lint also reads. Runnable set = commands + observations, in file order — identical membership and numbering to today's non-`skip` set, so `test.sh` markers (`@@ BLOCK file n`) and `checks.sh` block references are unchanged. `killercoda.js` matches windows against the running current window exactly where the old guessed-actor check did; markers, `show` rendering and exec rendering are unchanged.

## Verification

From `/code/singular-demo-issue-22`, each journaled as `GATE-PASS`/`GATE-FAIL`:

1. `node demos/demo1/killercoda.js .` then `git diff --exit-code killercoda/`
2. repository lint entry point (runs the new fence check among its steps)
3. `PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 nix develop --command bash demos/demo1/test.sh` (~5 min)
4. docs strict build with attributed blocks rendered as code blocks

Plus an ad-hoc (uncommitted) per-block exit-status cross-check during (3): every fence's real exit must equal its declared `status` (0 when absent).
