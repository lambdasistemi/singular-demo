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

# Run every block of the tutorial against a fresh private devnet (about ten minutes).
test-demo1:
    nix develop --quiet -c bash demos/demo1/test.sh

# Build the documentation site from the logs of a run:  just docs RUNBOOK_LOG DEMO_RUN_LOG
docs runbook_log demo_log:
    nix shell .#docs-env --command bash docs/build.sh {{ runbook_log }} {{ demo_log }}

# Build the Ubuntu kit and check its contents.
kit:
    nix build --quiet .#kit
    nix run --quiet .#kit-verify

# Move to another Singular release: just bump v0.13.2
bump version:
    nix develop .#dev --command bash tools/bump.sh {{ version }}
