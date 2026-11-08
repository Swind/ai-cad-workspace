"""Read-only probe: CLI status plus authenticated HTTP, never start an engine."""
import json
from pathlib import Path
import subprocess
import urllib.request

data = json.loads(subprocess.check_output(['cad', 'status', '--json'], timeout=6))
assert data and data.get('ok') is True and (data.get('serving') or {}).get('port') == 3245
# engine/registry.py: TOKEN = "engines/token" (verified through v0.11.1).
token = (Path.home() / '.local/state/cad/engines/token').read_text().strip()
request = urllib.request.Request('http://127.0.0.1:3245/', headers={'Authorization': 'Bearer ' + token})
with urllib.request.urlopen(request, timeout=4) as response:
    assert response.status == 200
