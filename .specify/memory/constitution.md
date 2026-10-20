# Singular demos Constitution

This repository delivers demonstrations of Singular on a private Cardano test chain, each in several ways: a
recorded run to read, a Killercoda scenario, a Codespaces tutorial, and the Ubuntu kit and Nix shell to run on a
machine of one's own. The principles below decide what is accepted into it.

## Core Principles

### I. The record outranks the implementation

Docs, the tutorial text, the specification and the acceptance criteria outrank code, always. Code is regenerable
from a good record; the record is not regenerable from code. A change ships its documentation in the same diff,
acceptance is written in terms of what a learner sees before any code is written, and a cut lands on
implementation scope, never on the record.

### II. One source, generated outputs

The tutorial of a demo is written once, in `demos/<demo>/s*.md`. The Killercoda scenarios, the website pages, the
Codespaces lessons and the recorded run are generated from it and are never edited by hand. The Singular version
is written once, in `flake.nix`. A check fails the build when a committed generated file is not the one the
source generates.

### III. Every promise has a job that breaks when it breaks

The README promises ways to meet a demo. Each promise is backed by a CI job that plays it on the kit built in the
same run: the clean-Ubuntu run of the kit, the Killercoda scenarios, the Codespaces tutorial, the site built from
real runs. A way that no job exercises is not offered.

### IV. The environments share the play

Killercoda and Codespaces run the same scripts of the play (`demos/<demo>/play/`): install the kit, make the
folders, set up the shell, start the windows. A difference between environments is a hook in a shared script, never
a copy of it.

### V. Evidence over assertion, and text for the moment

A run shown is a real run, made by CI, with its real results. The tutorial states only what a check backs and
names what the demo does not show. Each sentence, variable and file is introduced at the step that uses it: no
forward pointers, no explanation of the machinery, no option the step does not need.

### VI. A reproducible kit with a clean-room proof

The kit is built by Nix from `flake.lock`, needs no Nix, Docker or root on the target, and is proved in a clean
Ubuntu with no network. A numbered release is created once by pushing a tag that names the pinned Singular
version, from a CI run that passed, and is never overwritten.

### VII. Nix-first tooling, CI on the nixos runners

Every tool the checks use is in the flake, so `nix flake check` and `just ci` are the local gate and the hosted CI
runs the same code. Jobs run on the self-hosted `nixos` runners after a Build Gate. A job that needs Docker or a
real Ubuntu runs on a GitHub-hosted runner, and CI says why in a comment.

### VIII. A public repository reads as one

Pull request descriptions answer what changed, why, how to verify and the limits, for a reader who has only this
repository; every claim is checkable by that reader. Commits follow Conventional Commits. Nothing in the
repository or its history names the internal arrangements of whoever wrote it.

## Constraints

- Everything runs on a private test chain. No demo touches a public network, and no secret or real key is used or
  needed; passphrases in the tutorial are throwaway.
- A Codespace is created under the learner's own account and quota. The tutorial server binds to loopback and its
  port stays private.
- The kit targets Ubuntu 24.04 on x86_64; the Nix shell targets `x86_64-linux`. Other systems are not claimed.

## Development workflow

- Work happens on a branch and lands by pull request; the `main` ruleset requires every CI check.
- A new demo is a folder `demos/<demo>/` with its steps, generator and tests, a page in `docs/`, and its jobs in CI.
- A change to the Singular version edits the pins and the README in one pull request, regenerates the scenarios,
  and is followed by a tag.

## Governance

This constitution gates planning. An amendment states which principle changes and why, lands by pull request, and
updates the version and date below.

**Version**: 1.0.0 | **Ratified**: 2026-10-20 | **Last Amended**: 2026-10-20
