# Implementation Plan: Ship the stepper in the kit and on Homebrew

**Branch**: `feat/24-ship-the-stepper` | **Date**: 2026-10-23 | **Spec**: `specs/024-ship-the-stepper/spec.md`

## Summary

Pin `tutorial-stepper v0.4.1` in the flake; carry its static x86_64-linux binary (hash-checked against the release `SHA256SUMS`) and both tutorial directories in the kit; delete `drive.sh`, `drive-run.sh` and the `drive-rc.sh` hooks; prove the kit with a stepper-based container test (`kit/stepper-run.sh`, `--path short`, receipt checks); ship two Homebrew formulas from `homebrew/` templates (`singular@0.16` from the v0.16.0 macOS bundle, `singular-demo` with the tutorials and a play command), pushed by the release workflow with an org-app token; prove macOS with a `macos-14` job installing from a temporary local tap and playing Demo 1's shortest path; document both install ways in the README and the site.

## Technical Context

**Language/Version**: bash + Node.js 22 (existing scripts; one new `singular-demo` play script); tutorial-stepper 0.4.1 static binary via flake input
**Primary Dependencies**: `tutorial-stepper v0.4.1` (flake input `github:lambdasistemi/tutorial-stepper/v0.4.1`); Singular v0.16.0 macOS bundle; `tx-inspect`/`tx-diff` 0.2.3.0; Homebrew `jq`, `tmux`, `bash`, `node`
**Storage**: N/A (kit tarball + two formula files + tutorial directories already in the repo)
**Testing**: `kit/verify.sh`, `kit/stepper-run.sh` in a clean Ubuntu container, formula render test, `actionlint`, `tutorial-stepper check` + `play --auto` on both tutorials, `macos-14` tap-install + shortest-path play
**Target Platform**: `x86_64-linux` (kit, nixos runners) + `macos-14` (arm64, Homebrew job)
**Project Type**: tutorial repository (owned: `kit/`, `homebrew/`, CI, README/docs; `demos/*` only if the kit layout forces it)
**Performance Goals**: pull-request CI stays about 10 minutes (shortest windows 60000/30000 everywhere whole runs play)
**Constraints**: every CI job stays a required check (`runs-on: nixos` except Ubuntu/Docker and `macos-14` jobs, each with its why-comment); any added/renamed job listed in `COMPLETE`; release-please untouched; Conventional Commits, no attribution
**Scale/Scope**: 1 flake input move; kit build + verify + 1 new container test, 3 deletions; 2 formula templates + render script + test; release workflow tap push; 1 new CI job; README + site pages

## Constitution Check

- I. Record outranks implementation: spec/plan/tasks first (this commit), docs ride with each behaviour commit. No departure.
- II. One source, generated outputs: tutorials stay the source; kit carries them verbatim; formulas render from templates (a check fails when a committed formula is not the one the template generates). No departure.
- III. Every promise has a job: kit play proven by `terminal` (stepper-run), macOS play proven by the new `macos-14` job; no install way offered without its job. No departure.
- IV. Environments share the play: Killercoda/Codespaces scripts untouched; only `drive.sh` + its hooks go. No departure.
- V. Evidence over assertion: transcripts + receipt checks kept; macOS proof is the CI job, stated in `COMPLETE`. No departure.
- VI. Reproducible kit, clean-room proof: binary pinned by hash, container has no network. No departure.
- VII. Nix-first, nixos runners: new checks in the flake where they run on nixos; Ubuntu/Docker and macOS jobs keep their why-comments. No departure.
- VIII. Public repo reads as one: PR answers what/why/verify/limits; no internal arrangements named. No departure.

No complexity-table entry: no principle is departed from.

## Project Structure

```text
specs/024-ship-the-stepper/
├── spec.md
├── plan.md
└── tasks.md

kit/
├── build.nix        # + bin/tutorial-stepper (v0.4.1, SHA256SUMS-checked) + share/tutorials/{demo1,pay-by-name}
├── verify.sh        # + binary + tutorials checks
├── stepper-run.sh   # NEW: clean-Ubuntu stepper play of --path short + receipt checks (both scenarios)
├── drive.sh drive-run.sh  # DELETED
├── README.txt       # tutorial-stepper play instead of drive.sh
└── revision         # raised (kit contents change under the same Singular release)

demos/demo1/play/drive-rc.sh demos/pay-by-name/play/drive-rc.sh  # DELETED (prompt hooks)
demos/demo1/play/ demos/pay-by-name/play/  # the rest stays for Killercoda/Codespaces/demo.sh

homebrew/            # NEW
├── singular-at-0.16.rb.in singular-demo.rb.in  # formula templates
├── render.sh        # version+sha+url -> Formula/*.rb (release + PR-local modes)
└── test-render.sh   # TDD subject: rendering + dependency/URL/sha assertions

flake.nix flake.lock  # tutorial-stepper v0.4.0 -> v0.4.1
.github/workflows/
├── ci.yml           # terminal job runs stepper-run.sh; NEW macos-14 homebrew job
└── release.yml      # NEW tap job: render + push formulas with org-app token (tags only)

README.md docs/index.md docs/<install page>  # both install ways
justfile tools/      # render/play/kit recipes ride with the behaviour
```

**Structure Decision**: kit carries the tutorial directories verbatim (no fork); formulas render from templates (no hand-edited `.rb` in the repo). The `terminal` job keeps its name (script swap only); the new jobs (`homebrew` CI job, `tap` release job) are listed in `COMPLETE`.

## Design

- **Flake**: `inputs.tutorial-stepper.url = "github:lambdasistemi/tutorial-stepper/v0.4.1"`; `flake.lock` via `nix flake update --update-input tutorial-stepper` only. Pass the package into `kit/build.nix` as `tutorialStepper` (as `singular`/`devnet` are passed today).
- **Kit build**: copy `tutorialStepper/bin/tutorial-stepper` to `$OUT/bin/tutorial-stepper`; assert its sha256 equals the pinned line in `kit/tutorial-stepper.sha256` (the v0.4.1 `SHA256SUMS` line for `tutorial-stepper-0.4.1-x86_64-linux`: `8dfd712f…`); fail the build otherwise. Copy `demos/demo1` to `$OUT/share/tutorials/demo1` and `demos/pay-by-name` to `$OUT/share/tutorials/pay-by-name` (whole directories: `tutorial.toml`, `setup.sh`, pages, `play/stepper.sh`, `play/helpers.sh`). Keep `demo.sh`, `play/` scenario copies and sink-tools as they are. Raise `kit/revision` by hand (contents change under Singular v0.16.0).
- **Kit verify**: `bin/tutorial-stepper` present and executable; `--version` prints 0.4.1; its sha256 equals the pinned line; both `share/tutorials/*/tutorial.toml` present; `tutorial-stepper check` passes on both carried tutorials (with the kit's binary); no `drive.sh`/`drive-rc.sh` in the kit; existing checks (no store paths, RPATH, node/sink) unchanged.
- **Container test** (`kit/stepper-run.sh`, same envelope as `drive-run.sh`: `TARBALL`, `SCENARIO`, `IMAGE`, `OUT`): assert no tmux/node in the image; unpack; put kit `bin/` on `PATH`; `bin/tutorial-stepper play --auto share/tutorials/demo1 --path short --run /out/run --run-setup --transcript /out/transcript.toml` (pay-by-name: `share/tutorials/pay-by-name`, no `--path`); run the matching receipt check (`demos/demo1/play/check-receipts.sh`, `demos/pay-by-name/check-run.sh` — carried in the repo checkout, as `drive-run.sh` mounts them); keep transcript + run folder + chain-gone + no-error-lines evidence. One command per block is already true (#22/#26); the test fails otherwise at the first multi-command surprise.
- **Deletions**: `kit/drive.sh`, `kit/drive-run.sh`, `demos/demo1/play/drive-rc.sh`, `demos/pay-by-name/play/drive-rc.sh`; every reference (`build.nix` copies, `verify.sh` store-path scan, `container-run.sh` if it names them, CI `terminal` job, README/docs/justfile, `killercoda` only if it sources them — it does not) goes in the same commits.
- **Formulas**: `homebrew/render.sh --tag v0.16.0-1 --out Formula/` writes `Formula/singular@0.16.rb` (url `https://github.com/lambdasistemi/singular/releases/download/v0.16.0/singular-0.16.0-aarch64-darwin.tar.gz`, sha256 `920fe4b6…`, class `SingularAT016`) and `Formula/singular-demo.rb` (url the tag tarball of this repo, sha256 computed at release time; `depends_on` the versioned singular, `tx-inspect`, `tx-diff`, `jq`, `tmux`, `tutorial-stepper`, plus `bash` and `node` with a comment citing the runtime lesson; installs `demo1/` + `pay-by-name/` to `pkgshare`, `sink-tools.cjs` + `plutus.json`, links `bin/singular-demo`: `singular-demo` plays Demo 1, `singular-demo pay-by-name` plays pay-by-name, both via `tutorial-stepper play` with `--run $HOME/<run>` default and `--run-setup` passthrough). `--local <tutorial-tarball>` mode rewrites only the url for the PR job. `homebrew/test-render.sh` asserts the dependency lines, urls, shas and the play command; it is the TDD subject (RED before templates exist).
- **Release workflow**: new `tap` job (tags only, after `ci`): download nothing new (sha of the tag tarball via `gh release view`), render with real urls, clone the tap with the org-app token (`vars.CI_APP_ID`/`secrets.CI_APP_PRIVATE_KEY`, `repositories: homebrew-tap`), commit `Formula/singular@0.16.rb` + `Formula/singular-demo.rb`, push. PRs never run it (tag trigger only).
- **macOS CI job** (`homebrew`, `runs-on: macos-14`, with the why-comment): tar the two tutorial dirs from the PR; render with `--local`; create a temp local tap (`brew tap-new` style temp formula dir); `brew install --formula ./singular-demo.rb` (deps resolve from the real tap); `brew test`; then `tutorial-stepper play --auto` Demo 1 `--path short --run-setup` unattended. Proves what cannot be proved on Linux; named in `COMPLETE` with the Linux caveat.
- **Docs**: README "On your own machine" + `docs/index.md` (and the install page if one exists): Linux kit section says `tutorial-stepper play share/tutorials/demo1` (interactive) and the `--auto --path short` form; macOS section says `brew install lambdasistemi/tap/singular-demo` + `singular-demo` / `singular-demo pay-by-name`. `justfile`: `render-formulas`, `test-demo1-kit` (build kit, play from it), existing recipes untouched.

## Verification

From `/code/singular-demo-issue-24`, each journaled as `GATE-PASS`/`GATE-FAIL`:

1. `nix build .#kit` then the kit holds `bin/tutorial-stepper` and both tutorials; `kit/verify.sh` (or `nix run .#kit-verify`) passes.
2. The kit's container test plays Demo 1's shortest path with the stepper in a clean Ubuntu container and the receipt checks pass.
3. `nix shell nixpkgs#actionlint -c actionlint` clean; the formulas render from their templates and the rendering test passes.
