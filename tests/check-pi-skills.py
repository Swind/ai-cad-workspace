"""Check real Pi/OMP discovery of the installed CAD skills, without an LLM."""
import json
from pathlib import Path
import subprocess

expected = {p.name for p in (Path.home() / '.local/state/cad/plugin/skills').iterdir()
            if (p / 'SKILL.md').is_file()}
assert expected
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
