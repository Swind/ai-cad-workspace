# AI CAD Workspace

一個 Linux amd64 Container，使用 Process Compose 管理 Xvfb、Herdr Core、Ovis 與 text-to-cad。預裝 OpenCode、Codex、Claude Code；Host 只需要 Docker Engine 與 Compose。

## 部署

```bash
git clone git@github.com:Swind/ai-cad-workspace.git
cd ai-cad-workspace
mkdir -p home workspace
# 不覆蓋已有設定；token 由容器工具產生，不輸出到畫面。
test ! -e .env && (
  umask 077
  printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)"
  printf 'IMAGE=ghcr.io/swind/ai-cad-workspace:main\n'
  printf 'OVIS_TOKEN='
  docker run --rm --entrypoint python python:3.14.0-slim-bookworm \
    -c 'import secrets; print(secrets.token_hex(32))'
) > .env
docker compose pull
docker compose up -d
docker compose logs -f
```

首次 GHCR 發布完成前可用 `docker compose build && docker compose up -d`。Private Repository 的 GHCR package 可能需要先 `docker login ghcr.io`，或在 GitHub 調整 Package visibility。

Ovis：`http://<host-ip>:7317`，使用 `.env` 的 token 認證。CAD Viewer：`http://<host-ip>:3245`，模型連結須保留 CAD 自己產生的認證資訊，見下方。

## Shell 與 Agent 登入

Image 的 root entrypoint 只做 UID/GID 初始化，所有服務降權執行。`docker exec` 不會自動繼承降權，請使用：

```bash
docker compose exec --user "$(id -u):$(id -g)" ai-cad bash
# 以下在容器 shell：
/opt/ai-cad/scripts/setup-cad-agents.sh
codex login --device-auth
claude
opencode
```

setup 命令使用 Image 內固定 release 的 plugin：Codex／Claude Code 安裝完整 plugin，OpenCode 連結同版 skills，沒有為同一 Agent 重複安裝 skills + plugin。MCP config 指向 `/opt/cad/bin/cad-mcp`，避免 uvx 在啟動時另行下載 runtime。每次升級後可重新執行；既有不同來源的 text-to-cad plugin 請先依各 Agent 官方命令移除，避免重複。

Codex 使用 device login；Claude Code 首次執行依提示登入；OpenCode 使用 `/connect`。需要各自可用的帳戶／Provider，CI 不包含私人登入。API Key 可於個人 shell 使用 provider 官方環境變數設定，勿寫入 image 或 Git。

從 Ovis 開啟 Agent Pane，或在容器 shell 使用 `hc run --bg --name work codex`。個別 Agent 退出後不會被 Process Compose 強制重開。瀏覽器關閉不終止 Pane；容器重啟會終止原程序，改用 `codex resume`、`claude --resume` 或 OpenCode 的 Session 選單恢復已保存對話。

## CAD

```bash
# 容器 shell
/opt/ai-cad/scripts/smoke-cad.sh
cad run /workspace/my-model.py
cad snapshot /workspace/my-model.xbf /workspace/iso.png --camera iso
cad export /workspace/my-model.xbf /workspace/model.step /workspace/model.stl
python /opt/ai-cad/scripts/cad-link.py <host-ip> /workspace/my-model.xbf
```

最後一個命令印出帶認證的 LAN URL，只替換 authority，保留路徑與 token。請不要把完整連結貼入公開日誌。

## Process Compose 管理

以下在非 root 容器 shell 執行。管理使用 `/run/ai-cad/process-compose.sock`，沒有額外管理 TCP port 或 TUI。

```bash
process-compose -U process list
process-compose -U process get cad -o json
process-compose -U process logs cad --tail 100
process-compose -U process logs ovis --follow
process-compose -U process restart cad
process-compose -f /opt/ai-cad/config/process-compose.yaml --dry-run
/opt/ai-cad/tests/test-config.sh
```

所有服務輸出亦可使用 `docker compose logs -f ai-cad` 查看。Supervisor 的排程／restart 原因另在 `/run/ai-cad/supervisor.log`。各服務最多自動重啟 5 次，間隔 5 秒；耗盡後保留失敗狀態與日誌，Docker healthcheck 會失敗。Docker 不會因 unhealthy 自行重啟，修正原因後手動 restart 服務／容器。

## 診斷

```bash
/opt/ai-cad/scripts/doctor.sh
xdpyinfo -display :99
glxinfo -B
hc server status --json
curl -fsS http://127.0.0.1:7317/api/health
cad status --json
/opt/ai-cad/scripts/healthcheck.sh
```

Snapshot 失敗時，先檢查 `DISPLAY=:99`、`LIBGL_ALWAYS_SOFTWARE=1`、Xvfb readiness 與 `glxinfo -B`，再跑 smoke test。HTTP 可用不代表 OCCT 渲染正常；完整渲染只在 smoke test／CI 執行。

## 掛載、升級與回滾

- `./workspace:/workspace`：模型原始碼、STEP、STL、PNG。
- `./home:/home/agent`：Agent 認證／對話、hc/Ovis 狀態、CAD token／registry／cache。備份時視為秘密資料。
- `PUID/PGID` 部署時設定，Image 不固定為 Host 1000。啟動不遞迴 chown 掛載目錄；權限不符會退出。
- 一般 Linux Docker bind mount 支援 UID/GID 對應；rootless Docker、userns-remap、NFS/ACL 需自行配置映射。

升級前停止容器，備份兩個掛載目錄並記錄當前 image digest；將 `.env` 的 `IMAGE` 設為新版本 digest，執行 `docker compose pull && docker compose up -d`，再執行 doctor／smoke test。回滾需停止容器，還原舊 digest 與升級前的 **home/workspace 備份**；上游狀態格式可能只支援向前遷移。

此環境限可信任 LAN。不掛載 Host Docker Socket 或整個 Home，不使用 privileged。LAN HTTP 上的 token 未加密；若網路不可信應部署 TLS 入口。

## 測試與發布

```bash
docker build -t ai-cad-workspace:test .
bash tests/test-container.sh ai-cad-workspace:test
TEST_UID=23456 TEST_GID=23457 bash tests/test-container.sh ai-cad-workspace:test
```

PR/main 執行 CI；main、`v*` tag 與手動 Release workflow 發布 GHCR。Release 在本身 workflow 內測試**同一份 Image**再 push。`main` 不更新 `latest`；只有穩定 `vX.Y.Z` 更新 `latest` 與 `vX.Y`。digest 與 smoke PNG 在 Actions artifacts／summary。

版本與取捨：[上游矩陣](docs/upstream-matrix.md)、[決策](docs/decisions.md)。實際驗收狀態以 [驗收紀錄](docs/acceptance.md) 為準。
