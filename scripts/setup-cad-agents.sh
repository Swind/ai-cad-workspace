#!/bin/bash
# Explicit, offline integration from the release already installed in this image.
set -euo pipefail
[[ $(id -u) != 0 ]] || { echo 'Run this as the mapped agent user' >&2; exit 1; }
cad plugin >/dev/null
python - <<'PY'
import json
import os
import subprocess
import tomllib
from importlib.metadata import version
from pathlib import Path
root = Path.home() / '.local/state/cad/plugin'
# Deployment config, not runtime source: use the preinstalled MCP shim instead of
# uvx downloading another Python/environment into the home bind mount.
# Claude Code's 0.11.9 plugin is skills-only; Codex still starts MCP.
for name in ('codex.mcp.json', 'claude.mcp.json', 'cursor.mcp.json', 'mcp.json', 'gemini-extension.json'):
    path = root / name
    data = json.loads(path.read_text())
    server = data['mcpServers']['cad']
    server['command'] = '/opt/cad/bin/cad-mcp'
    server['args'] = []
    path.write_text(json.dumps(data, indent=2) + '\n')
for directory in ('.config/opencode/skills', '.pi/agent/skills', '.omp/agent/skills'):
    skills = Path.home() / directory
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

# Only add our local marketplace once. Never replace another source's catalog.
identifier = 'text-to-cad@text-to-cad'
codex_home = Path(os.environ.get('CODEX_HOME', Path.home() / '.codex'))
config = codex_home / 'config.toml'
data = tomllib.loads(config.read_text()) if config.exists() else {}
market = data.get('marketplaces', {}).get('text-to-cad')
if market is None:
    subprocess.run(['codex', 'plugin', 'marketplace', 'add', str(root)], check=True)
elif market.get('source_type') != 'local' or Path(market.get('source', '')).resolve() != root.resolve():
    raise SystemExit('Refusing to replace your existing Codex text-to-cad marketplace')
# Codex caches real copies; add again on upgrades or when the MCP config needs repair.
cache = codex_home / 'plugins/cache/text-to-cad/text-to-cad' / version('cad-server')
if (identifier not in data.get('plugins', {})
        or not (cache / 'codex.mcp.json').is_file()
        or (cache / 'codex.mcp.json').read_bytes() != (root / 'codex.mcp.json').read_bytes()):
    subprocess.run(['codex', 'plugin', 'add', identifier], check=True)

markets = json.loads(subprocess.check_output(
    ['claude', 'plugin', 'marketplace', 'list', '--json'], text=True))
market = next((entry for entry in markets if entry['name'] == 'text-to-cad'), None)
if market is None:
    subprocess.run(['claude', 'plugin', 'marketplace', 'add', str(root)], check=True)
elif (market.get('source') != 'directory'
      or Path(market.get('path') or market.get('installLocation') or '').resolve() != root.resolve()):
    raise SystemExit('Refusing to replace your existing Claude text-to-cad marketplace')
plugins = json.loads(subprocess.check_output(['claude', 'plugin', 'list', '--json'], text=True))
installed = [entry for entry in plugins if entry['id'] == identifier]
if not installed:
    subprocess.run(['claude', 'plugin', 'install', identifier], check=True)
elif any(entry.get('version') != version('cad-server') for entry in installed):
    subprocess.run(['claude', 'plugin', 'update', identifier], check=True)
PY
codex plugin list --json
claude plugin list
