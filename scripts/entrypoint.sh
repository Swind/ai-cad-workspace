#!/bin/bash
set -euo pipefail
fail() { echo "entrypoint: $*" >&2; exit 1; }
[[ ${PUID:-} =~ ^[1-9][0-9]*$ && ${PGID:-} =~ ^[1-9][0-9]*$ ]] || fail 'PUID/PGID must be positive non-root numeric IDs'
[[ -n ${OVIS_TOKEN:-} && ${OVIS_TOKEN} != replace-with-random-token ]] || fail 'Set a random OVIS_TOKEN in .env'
if [[ $(id -u) == 0 ]]; then
  existing=$(getent passwd "$PUID" | cut -d: -f1 || true)
  [[ -z $existing || $existing == agent ]] || fail "UID $PUID already belongs to $existing"
  getent group "$PGID" >/dev/null || groupadd -g "$PGID" host-agent
  # usermod may chown HOME: temporarily move the passwd home, never the bind mount.
  usermod -d /nonexistent agent
  usermod -u "$PUID" -g "$PGID" agent
  usermod -d /home/agent agent
  install -d -m 700 -o "$PUID" -g "$PGID" /run/ai-cad
  install -d -m 700 -o "$PUID" -g "$PGID" /tmp/opencode
  install -d -m 1777 /tmp/.X11-unix
  exec gosu "$PUID:$PGID" "$0" "$@"
fi
[[ $(id -u) == "$PUID" && $(id -g) == "$PGID" ]] || fail 'Runtime UID/GID mismatch'
export HOME=/home/agent XDG_RUNTIME_DIR=/run/ai-cad
for dir in "$HOME" /workspace /run/ai-cad; do
  [[ -d $dir && -w $dir ]] || fail "$dir is not writable by $PUID:$PGID; create/fix the host mount ownership before starting (rootless/NFS may require mapping)"
done
umask 077
mkdir -p "$HOME/.config/process-compose" "$HOME/.local/state" "$HOME/.cache"
cd /workspace
if (( $# )); then exec "$@"; fi
exec process-compose -t=false -U --ordered-shutdown --log-no-color \
  -L /run/ai-cad/supervisor.log -f /opt/ai-cad/config/process-compose.yaml up
