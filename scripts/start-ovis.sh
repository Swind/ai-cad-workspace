#!/bin/bash
set -euo pipefail
cd /opt/ovis
# Built during image construction; no runtime build or managed auto-updater.
exec bun run server/index.ts
