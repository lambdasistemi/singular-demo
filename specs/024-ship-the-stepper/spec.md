# Feature Specification: Ship the stepper in the kit and on Homebrew

**Feature Branch**: `feat/24-ship-the-stepper`
**Created**: 2026-10-23
**Status**: Specified
**Input**: Issue 24, "Ship the stepper in the kit and on Homebrew" (epic 21, after #23, #26, tutorial-stepper#3 and tutorial-stepper#18)

## User Scenarios & Testing

### User Story 1 — A learner installs the demo and plays it with the stepper (Priority: P1)

As a learner, I install the demo (the kit on Linux, or `brew install lambdasistemi/tap/singular-demo` on a Mac) and play it with tutorial-stepper's terminal face.

**Why this priority**: This is the whole issue. `kit/drive.sh` and its prompt hooks go away; both tutorials already play on the stepper (#23 and #26).

**Independent Test**: On Linux, build the kit, unpack it on a clean machine, put its `bin/` on `PATH`, and run `tutorial-stepper play` on the carried tutorial: the page sits beside the acting window and Enter runs each command. On a Mac, `brew install lambdasistemi/tap/singular-demo` then the command the formula gives plays Demo 1's shortest path unattended.

**Acceptance Scenarios**:

1. **Given** the kit, **When** a learner unpacks it, **Then** it carries the `tutorial-stepper` binary and both tutorials; `kit/drive.sh` and its prompt hooks are gone, and the README and the site say `tutorial-stepper play` instead.
2. **Given** `lambdasistemi/homebrew-tap`, **When** the release workflow runs, **Then** the tap gains a versioned formula for the pinned Singular release (`singular@0.16` while pinned to v0.16.0, from that release's macOS bundle) and `singular-demo`, which depends on it, `tx-inspect`, `tx-diff`, `jq`, `tmux` and `tutorial-stepper`, installs both tutorials, and gives a command that plays Demo 1 (and pay-by-name by name) with `tutorial-stepper play`.
3. **Given** a pull request, **When** CI finishes, **Then** a `macos-14` job has installed `singular-demo` from a temporary local tap built from the pull request and played Demo 1's shortest path unattended; nothing was pushed to the tap.
4. **Given** the README and the documentation site, **When** a learner reads how to install, **Then** both ways (kit on Linux, Homebrew on a Mac) are described.

### Edge Cases

- The macOS system bash is too old for the stepper's prompt hook (tutorial-stepper#18: needs bash 4+, macOS ships 3.2); the formula ensures a current bash alongside tmux.
- The pay-by-name story needs `sink-tools` on Node.js; the formula brings Homebrew's node and installs the tools with the tutorials.
- Intel Macs are not built; the Linux kit stays x86_64-only (constitution: Ubuntu 24.04 on x86_64).
- An untested settings combination is playable but announced once by the stepper; the kit and formula play tested paths.

## Requirements

### Functional Requirements

- **FR-001**: `tutorial-stepper` moves to v0.4.1 everywhere: the flake input moves from v0.4.0 (`--update-input tutorial-stepper` only), the kit carries the static `tutorial-stepper-0.4.1-x86_64-linux` from that release checked against its `SHA256SUMS`, and the `singular-demo` formula depends on `lambdasistemi/tap/tutorial-stepper` (at 0.4.1).
- **FR-002**: The kit carries both tutorials (`demos/demo1/`, `demos/pay-by-name/` with their `tutorial.toml`, set-up scripts and pages) and `bin/tutorial-stepper`; `kit/drive.sh`, `kit/drive-run.sh` and the `drive-rc.sh` prompt hooks are deleted. The set-up scripts resolve programs from `PATH` at `--run-setup` time, so the carried tutorials run wherever the kit's `bin/` is on `PATH`.
- **FR-003**: A new kit container test (`kit/stepper-run.sh`) plays Demo 1's shortest path (`--path short`) with the kit's stepper in a clean Ubuntu container with no tmux, no node, no Nix and no network; the receipt checks pass on its run folder. The `terminal` CI job runs it (for both tutorials, as `drive-run.sh` did); the transcript and screens are kept as evidence.
- **FR-004**: `homebrew/` holds templates for `singular@0.16` (url: the v0.16.0 macOS bundle, sha256 from that release's `SHA256SUMS`) and `singular-demo` (depends on `lambdasistemi/tap/singular@0.16`, `tx-inspect`, `tx-diff`, `jq`, `tmux`, `tutorial-stepper`, plus `bash` and `node` for the runtime the lessons name; installs both tutorials from this repository's tag tarball; gives `singular-demo` playing Demo 1 and `singular-demo pay-by-name` with `tutorial-stepper play`). A render script produces the formulas from version, checksums and urls; the rendering is tested.
- **FR-005**: The release workflow pushes the rendered formulas to `lambdasistemi/homebrew-tap` with a token minted from the org app (`vars.CI_APP_ID` + `secrets.CI_APP_PRIVATE_KEY`, scoped to `homebrew-tap`); on pull requests nothing is pushed to the tap.
- **FR-006**: A `macos-14` CI job builds a tutorial tarball from the pull request, renders the formulas with the url rewritten to that local tarball, installs `singular-demo` from a temporary local tap, and plays Demo 1's shortest path unattended.
- **FR-007**: Every block stays one command per line; the stepper needs tmux and an interactive bash at run time (kit: its own tmux, host bash; macOS: Homebrew's tmux and bash).
- **FR-008**: Every behaviour ships its documentation in the same commit: README and site describe both install ways; `justfile` gains the local recipes (render formulas, play from the kit).
- **FR-009**: No committed change outside `kit/`, `demos/*/tutorial.toml|setup.sh` (only if the kit layout forces it, tutorials keep playing in the dev shell), `flake.nix`/`flake.lock`, `.github/workflows/`, `tools/`, `justfile`, `README.md`, `docs/`, `homebrew/` and `specs/024-ship-the-stepper/`. Killercoda, Codespaces and `demo.sh` keep working.

## Success Criteria

- **SC-001**: `nix build .#kit` holds `bin/tutorial-stepper` (0.4.1, hash equals the release `SHA256SUMS` line) and both tutorials; `kit/verify.sh` (or `nix run .#kit-verify`) passes.
- **SC-002**: The kit's container test plays Demo 1's shortest path with the stepper in a clean Ubuntu container and the receipt checks pass.
- **SC-003**: `nix shell nixpkgs#actionlint -c actionlint` is clean; the formulas render from their templates and the rendering test passes.
- **SC-004**: Repository lint, format check and the documentation build pass; every check of the pull request is green.

## Assumptions

- tutorial-stepper v0.4.1 (readline refusal, signal cleanup, Homebrew formula at 0.4.1) is released; no stepper format change is needed.
- Both tutorials play on v0.4.0 today; v0.4.1 changes no format, only the runtime guards.
- The Singular v0.16.0 macOS bundle and its checksum exist on that release (formula `singular.rb` already names them).
- macOS cannot be proved here; the proof is the `macos-14` CI job, which the parent reads.
