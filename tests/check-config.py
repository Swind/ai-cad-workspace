import json
from pathlib import Path
import jsonschema
import yaml

root = Path('/opt/ai-cad/config')
schema = json.loads((root / 'vendor/process-compose-schema.json').read_text())
config = yaml.safe_load((root / 'process-compose.yaml').read_text())
jsonschema.validate(config, schema)
print('PASS: pinned upstream Process Compose JSON Schema')
