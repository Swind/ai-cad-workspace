"""Exercise Ovis's real hc-backed terminal over separate HTTP connections."""
import json
import os
import subprocess
import time
import urllib.request
from urllib.parse import urlencode

base = 'http://127.0.0.1:7317'


def call(path, body=None):
    headers = {'Authorization': 'Bearer ' + os.environ['OVIS_TOKEN'], 'Origin': base}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    with urllib.request.urlopen(urllib.request.Request(base + path, data=data, headers=headers), timeout=30) as response:
        return json.load(response)


expected = subprocess.check_output(['codex', '--version'], text=True).strip()
created = call('/api/workspace/create', {'cwd': '/workspace', 'label': 'CI real PTY'})
pane = created['pane_id']
call('/api/pane/input', {'pane_id': pane, 'text': 'codex --version\r'})
for _ in range(30):
    output = call('/api/pane/read?' + urlencode({'pane_id': pane, 'lines': 40}))
    if expected in json.dumps(output):
        break
    time.sleep(1)
else:
    raise AssertionError(output)
# A new HTTP client can still read the same terminal after the original closed.
assert expected in json.dumps(call('/api/pane/read?' + urlencode({'pane_id': pane})))
print('PASS: Ovis creates real hc pane, executes Codex CLI, reconnects to its output')
