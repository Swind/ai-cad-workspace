"""Check real Pi/OMP discovery of the installed CAD skills, without an LLM."""
import json
from pathlib import Path
import subprocess

root = Path.home() / '.local/state/cad/plugin'
expected = {'cad', 'engineering-drawing', 'fea', 'pcb', 'print3d', 'render',
            'robot-simulation', 'sendcutsend'}
bundled = {p.name for p in (root / 'skills').iterdir() if (p / 'SKILL.md').is_file()}
assert bundled == expected, (bundled, expected)
for name in ('codex.mcp.json', 'claude.mcp.json', 'cursor.mcp.json', 'mcp.json', 'gemini-extension.json'):
    server = json.loads((root / name).read_text())['mcpServers']['cad']
    assert server['command'] == '/opt/cad/bin/cad-mcp' and server['args'] == [], name
# Upstream intentionally gives Claude Code skills without its own MCP server.
assert 'mcpServers' not in json.loads((root / '.claude-plugin/plugin.json').read_text())
pi = json.loads(subprocess.check_output([
    'node', '--input-type=module', '-e',
    "import {loadSkills} from '/opt/agents/node_modules/@earendil-works/pi-coding-agent/dist/core/skills.js';"
    "console.log(JSON.stringify(loadSkills({cwd:'/workspace',includeDefaults:true,skillPaths:[]}).skills));",
], text=True, timeout=30))
omp = json.loads(subprocess.check_output(['omp', 'skill', 'list', '--json'], text=True, timeout=30))
for name, skills in (('Pi', pi), ('Oh My Pi', omp['skills'])):
    found = {skill['name'] for skill in skills}
    assert expected <= found, (name, expected - found)
    print(f'PASS: {name} discovers all {len(expected)} CAD skills')
