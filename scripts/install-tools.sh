#!/bin/bash
set -euo pipefail
source /opt/ai-cad/versions.env
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fetch() {
  curl --retry 3 -fsSL "$1" -o "$tmp/$2"
  printf '%s  %s\n' "$3" "$tmp/$2" | sha256sum -c -
}
fetch "https://github.com/F1bonacc1/process-compose/releases/download/v${PROCESS_COMPOSE_VERSION}/process-compose_linux_amd64.tar.gz" pc.tgz "$PROCESS_COMPOSE_SHA256"
tar -xzf "$tmp/pc.tgz" -C /usr/local/bin process-compose
fetch "https://releases.herdr.dev/core/${HC_VERSION}/herdr-core-linux-x86_64.tar.gz" hc.tgz "$HC_SHA256"
tar -xzf "$tmp/hc.tgz" -C /usr/local/bin herdr-core
ln -s herdr-core /usr/local/bin/hc
fetch "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" bun.zip "$BUN_SHA256"
unzip -q "$tmp/bun.zip" -d "$tmp"
install "$tmp/bun-linux-x64/bun" /usr/local/bin/bun
fetch "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" uv.tgz "$UV_SHA256"
tar -xzf "$tmp/uv.tgz" -C "$tmp"
install "$tmp/uv-x86_64-unknown-linux-gnu/uv" "$tmp/uv-x86_64-unknown-linux-gnu/uvx" /usr/local/bin/
git init /opt/ovis
git -C /opt/ovis remote add origin https://github.com/devswha/ovis.git
git -C /opt/ovis fetch --depth 1 origin "$OVIS_COMMIT"
git -C /opt/ovis checkout --detach FETCH_HEAD
mkdir -p /opt/ovis/bin
fetch "https://github.com/devswha/ovis/releases/download/v${OVIS_VERSION}/ovis-pty-sidecar-linux-x64" pty "$OVIS_PTY_SHA256"
install "$tmp/pty" /opt/ovis/bin/ovis-pty-sidecar
cd /opt/ovis
bun install --frozen-lockfile
bun run build
