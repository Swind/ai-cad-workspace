#!/bin/bash
set -euo pipefail
if [[ $(id -u) == 0 ]]; then
  exec gosu "$PUID:$PGID" env XDG_RUNTIME_DIR=/run/ai-cad "$0" "$@"
fi
check() {
  case "$1" in
    xvfb) timeout 5 xdpyinfo -display :99 >/dev/null ;;
    herdr) python /opt/ai-cad/scripts/check-herdr.py ;;
    ovis) curl -fsS --max-time 5 http://127.0.0.1:7317/api/health | jq -e '.ok == true' >/dev/null ;;
    cad) python /opt/ai-cad/scripts/check-cad.py ;;
    *) echo "Unknown service: $1" >&2; return 1 ;;
  esac
}
failed=0
if (( $# == 0 )); then set -- xvfb herdr ovis cad; fi
for name in "$@"; do
  if ! check "$name"; then echo "NOT READY: $name" >&2; failed=1; fi
done
exit "$failed"
