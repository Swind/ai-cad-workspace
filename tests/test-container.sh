#!/bin/bash
# Runs against the exact image later published by CI. No provider credentials.
set -euo pipefail
image=${1:-ai-cad-workspace:test}
name="ai-cad-test-$$"
root=$(mktemp -d "${TMPDIR:-/tmp}/ai-cad-test-XXXXXX")
uid=${TEST_UID:-$(id -u)}
gid=${TEST_GID:-$(id -g)}
[[ $uid != 0 ]] || uid=12345
[[ $gid != 0 ]] || gid=12345
cleanup() {
  # docker cp assigns local ownership to the caller, including alternate-UID runs.
  docker cp "$name:/workspace" "$root/artifacts" >/dev/null 2>&1 || true
  docker cp "$name:/run/ai-cad/supervisor.log" "$root/supervisor.log" >/dev/null 2>&1 || true
  docker logs "$name" > "$root/container.log" 2>&1 || true
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "Test evidence and workspace: $root"
}
trap cleanup EXIT
mkdir -p "$root/home" "$root/workspace"
docker run --rm --entrypoint sh -v "$root:/test" "$image" -c "chown $uid:$gid /test/home /test/workspace"
start() {
  docker run -d --name "$name" --init --stop-timeout 60 \
    --security-opt no-new-privileges:true \
    -e PUID="$uid" -e PGID="$gid" -e OVIS_TOKEN=ci-only-not-a-production-token \
    -v "$root/home:/home/agent" -v "$root/workspace:/workspace" \
    -p 127.0.0.1::7317 -p 127.0.0.1::3245 "$image" >/dev/null
}
as_agent() { docker exec --user "$uid:$gid" -e XDG_RUNTIME_DIR=/run/ai-cad "$name" "$@"; }
ready() {
  for ((i=0; i<90; i++)); do
    if as_agent /opt/ai-cad/scripts/healthcheck.sh >/dev/null 2>&1; then return; fi
    sleep 2
  done
  docker logs "$name"
  return 1
}
start
ready
as_agent /opt/ai-cad/tests/test-config.sh
as_agent /opt/ai-cad/scripts/setup-cad-agents.sh
# shellcheck disable=SC2016 # Expanded inside the container.
as_agent bash -ec 'test "$(id -u)" = "$PUID"; test "$(id -g)" = "$PGID"; touch /workspace/ownership; echo retained > "$HOME/persistence-marker"'
[[ $(stat -c '%u:%g' "$root/workspace/ownership") == "$uid:$gid" ]]
as_agent bash -ec 'process-compose -U process list; hc --version; codex --version; claude --version; opencode --version'
ovis_port=$(docker port "$name" 7317/tcp | cut -d: -f2)
cad_port=$(docker port "$name" 3245/tcp | cut -d: -f2)
curl -fsS "http://127.0.0.1:$ovis_port/api/health" | grep -q '"ok":true'
[[ $(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$cad_port/") == 403 ]]
as_agent python /opt/ai-cad/tests/check-viewer.py
as_agent python /opt/ai-cad/tests/check-ovis.py
as_agent /opt/ai-cad/scripts/smoke-cad.sh
# Real PTY lifecycle without a cloud LLM: hc owns the session, PC does not.
as_agent hc run --bg --name persistence --keep bash
as_agent hc send persistence 'printf "SESSION_MARKER\\n"'
as_agent hc read persistence --lines 20
for service in ovis cad herdr xvfb; do
  before=$(as_agent process-compose -U process get "$service" -o json)
  pid=$(printf '%s' "$before" | docker exec -i "$name" jq -r '.[0].pid')
  [[ $(as_agent stat -c '%u:%g' "/proc/$pid") == "$uid:$gid" ]]
  as_agent kill -KILL "$pid"
  recovered=false
  for ((i=0; i<60; i++)); do
    after=$(as_agent process-compose -U process get "$service" -o json)
    if printf '%s' "$after" | docker exec -i "$name" jq -e --argjson old "$pid" '.[0] | .pid > 0 and .pid != $old' >/dev/null; then
      recovered=true
      break
    fi
    sleep 2
  done
  [[ $recovered == true ]]
  ready
  echo "PASS crash recovery: $service"
done
as_agent process-compose -U process restart cad
ready
as_agent /opt/ai-cad/scripts/smoke-cad.sh
docker stop -t 60 "$name" >/dev/null
[[ $(docker inspect -f '{{.State.ExitCode}}' "$name") != 137 ]]
[[ $(docker inspect -f '{{.State.Pid}}' "$name") == 0 ]]
docker logs "$name" > "$root/before-recreate.log" 2>&1
docker rm "$name" >/dev/null
start
ready
# shellcheck disable=SC2016 # Expanded inside the container.
as_agent bash -ec 'test "$(cat "$HOME/persistence-marker")" = retained; test -f /workspace/ownership; hc ls'
as_agent hc get persistence
docker kill --signal=INT "$name" >/dev/null
timeout 60 docker wait "$name" >/dev/null
[[ $(docker inspect -f '{{.State.ExitCode}}' "$name") != 137 ]]
echo 'PASS: config, identity, GLX, services, CAD, recovery, stop, recreation'
