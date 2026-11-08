#!/bin/bash
# Explicit, offline integration from the release already installed in this image.
set -euo pipefail
[[ $(id -u) != 0 ]] || { echo 'Run this as the mapped agent user' >&2; exit 1; }
cad plugin >/dev/null
python - <<'PY'
import json
from pathlib import Path
root = Path.home() / '.local/state/cad/plugin'
# Deployment config, not runtime source: use the preinstalled MCP shim instead of
# uvx downloading another Python/environment into the home bind mount.
for name in ('codex.mcp.json', 'claude.mcp.json'):
    path = root / name
    data = json.loads(path.read_text())
    server = data['mcpServers']['cad']
    server['command'] = '/opt/cad/bin/cad-mcp'
    server['args'] = []
    path.write_text(json.dumps(data, indent=2) + '\n')
skills = Path.home() / '.config/opencode/skills'
skills.mkdir(parents=True, exist_ok=True)
# Remove only our broken links to skills retired by an upstream release.
for target in skills.iterdir():
    if (target.is_symlink() and not target.exists()
            and target.resolve().parent == (root / 'skills').resolve()):
        target.unlink()
for source in (root / 'skills').iterdir():
    target = skills / source.name
    if target.is_symlink() and target.resolve() == source.resolve():
        continue
    if target.exists() or target.is_symlink():
        raise SystemExit(f'Refusing to replace your existing skill: {target}')
    target.symlink_to(source, target_is_directory=True)
PY
codex plugin marketplace add "$HOME/.local/state/cad/plugin"
codex plugin add text-to-cad@text-to-cad
claude plugin marketplace add "$HOME/.local/state/cad/plugin"
claude plugin install text-to-cad@text-to-cad
claude plugin update text-to-cad@text-to-cad
codex plugin list --json
claude plugin list
