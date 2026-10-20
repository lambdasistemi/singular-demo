#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
url=http://localhost:8765
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  url="https://${CODESPACE_NAME}-8765.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi
printf '\n  SINGULAR — YOUR TUTORIAL\n\n  %s\n\n  Open this link in a browser to begin.\n  When finished, stop your Codespace at https://github.com/codespaces\n\n' "$url"
cat > START-HERE.md <<EOF2
# Your Singular tutorial is ready

[Open your tutorial]($url)

Open this link in a browser tab. It contains the instructions and terminal together.

Click the link above to open the tutorial. If this file appears as source, use the Markdown preview button in the editor.
You can also open port 8765 from the Ports panel. Keep it Private.

## Already have a Codespace? Update it here

In the Codespaces editor terminal:

\`\`\`bash
git pull --ff-only && bash tutorial/update.sh
\`\`\`

Then refresh the tutorial tab. No container rebuild. This ends the current shell and chain session; your files remain.

When finished, stop this Codespace at https://github.com/codespaces to stop compute usage.
EOF2
if [[ "${1:-}" == "--show" ]] && command -v code >/dev/null 2>&1; then
  code --reuse-window "$PWD/START-HERE.md" || true
fi
