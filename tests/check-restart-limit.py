"""Prove the pinned supervisor stops retrying a permanently failing process."""
import os
from pathlib import Path
import subprocess
import tempfile
import yaml

with tempfile.TemporaryDirectory(prefix='pc-restart-') as folder:
    root = Path(folder)
    counter = root / 'attempts'
    config = root / 'process-compose.yaml'
    config.write_text(yaml.safe_dump({
        'version': '0.5',
        'processes': {'broken': {
            'command': f'echo attempt >> {counter}; exit 23',
            'availability': {'restart': 'on_failure', 'backoff_seconds': 1, 'max_restarts': 2},
        }},
    }))
    env = {key: value for key, value in os.environ.items() if not key.startswith('PC_')}
    result = subprocess.run([
        'process-compose', '-t=false', '--no-server', '--disable-dotenv', '--log-no-color',
        '-L', str(root / 'supervisor.log'), '-f', str(config), 'up',
    ], env=env, timeout=20, capture_output=True, text=True)
    assert counter.read_text().splitlines() == ['attempt'] * 3
    log = (root / 'supervisor.log').read_text()
    assert 'exit_code=23' in log
    print('PASS: permanently failing process stops after initial attempt + 2 retries; exit', result.returncode)
