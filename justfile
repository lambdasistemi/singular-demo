# Recipes of this repository. Run them inside the development shell:
#   nix develop .#dev -c just ci

# The checks the hosted CI runs that need no container: format, lint, the flake checks.
ci: format-check lint check

# Check that the repository's own files are formatted.
format-check:
    nix run --quiet .#format-check

# Format the repository's own files.
format:
    nix run --quiet .#format

# Lint the repository and check that it agrees with itself (generated files, README version).
lint:
    nix run --quiet .#lint

# Build every flake check.
check:
    nix flake check --no-eval-cache

# Regenerate the Killercoda scenarios and the structure file from the step files.
generate:
    bash tools/generate.sh .

# Play Demo 1's shortest tested path with the stepper (about five minutes).
test-demo1:
    nix develop --quiet -c tutorial-stepper play --auto demos/demo1 --path short --run /tmp/demo1-run --run-setup --transcript /tmp/demo1-transcript.toml
    nix develop --quiet -c bash demos/demo1/play/check-receipts.sh /tmp/demo1-run

# Check that the Homebrew formulas render from their templates.
render-check:
    bash homebrew/test-render.sh

# Build the documentation site from the transcript of a run:  just docs TRANSCRIPT DEMO_LOG
docs transcript demo_log:
    nix shell .#docs-env --command bash docs/build.sh {{ transcript }} {{ demo_log }}

# Build the Ubuntu kit and check its contents.
kit:
    nix build --quiet .#kit
    nix run --quiet .#kit-verify

# Move to another Singular release: just bump v0.13.2
bump version:
    nix develop .#dev --command bash tools/bump.sh {{ version }}
