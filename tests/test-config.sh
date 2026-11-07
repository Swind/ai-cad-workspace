#!/bin/bash
set -euo pipefail
python /opt/ai-cad/tests/check-config.py
python /opt/ai-cad/tests/check-restart-limit.py
process-compose --disable-dotenv -f /opt/ai-cad/config/process-compose.yaml --dry-run
shellcheck -e SC1091 /opt/ai-cad/scripts/*.sh /opt/ai-cad/tests/*.sh
