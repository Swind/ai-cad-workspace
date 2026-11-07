#!/bin/bash
set -euo pipefail
dir=$(mktemp -d /workspace/smoke-XXXXXX)
cd "$dir"
cp /opt/ai-cad/tests/sample-model.py .
glxinfo -B
cad run sample-model.py
cad export plate.xbf plate.step plate.stl
cad snapshot plate.xbf top.png --camera top --width 800 --height 600
cad snapshot plate.xbf iso.png --camera iso --width 800 --height 600
python /opt/ai-cad/tests/check-geometry.py
echo "Artifacts: $dir"
