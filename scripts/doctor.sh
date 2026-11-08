#!/bin/bash
set -euo pipefail
id
for command in 'process-compose version' 'hc --version' 'codex --version' 'claude --version' 'opencode --version' 'pi --version' 'omp --version' 'bun --version' 'uv --version'; do
  bash -c "$command"
done
process-compose -U process list
/opt/ai-cad/scripts/healthcheck.sh
glxinfo -B
stat -c '%u:%g %a %n' /home/agent /workspace
