#!/bin/bash
set -euo pipefail
if [[ $# == 1 && $1 == connect ]]; then
  exec python /opt/ai-cad/scripts/hc-connect.py
fi
exec /usr/local/bin/hc "$@"
