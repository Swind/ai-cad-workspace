# AGENTS.md

## 專案定位與閱讀順序

這是 Linux amd64 的單容器 AI CAD 工作站，不是自行開發的 CAD 引擎，也不是多使用者隔離平台。Host 僅需 Docker Engine 與 Compose；Python、Node、Agent CLI 及 CAD kernel 都在 Image 中。

- 先讀 [README.md](README.md)，理解部署、操作與資料邊界。
- 改架構或權限前讀 [docs/decisions.md](docs/decisions.md)；不要重新引入已排除的設計。
- 版本來源見 [docs/upstream-matrix.md](docs/upstream-matrix.md)；實測狀態見 [docs/acceptance.md](docs/acceptance.md)。歷史 PASS 不代表本次變更已驗證。
- `AI-CAD-Workspace-Implementation-Plan.md` 是原始規格；與目前實作不同時，先查決策及驗收紀錄，不直接照舊規格改回。

## 檔案與資料邊界

| 路徑 | 用途／修改注意 |
| --- | --- |
| `Dockerfile`、`versions.env` | Image 組裝、版本、SHA256；base image 另固定 digest |
| `compose.yaml`、`.env.example` | Host 部署契約、UID/GID、ports 與掛載 |
| `config/process-compose.yaml` | 四個常駐服務的依賴、probe、有限重試與停止策略 |
| `config/vendor/` | 固定上游 Process Compose schema 及授權 |
| `requirements.in`、`requirements.lock` | Python 直接依賴與完整 hash lock |
| `agents/package.json`、`agents/package-lock.json` | 五款 Agent 的精確 npm 版本與 integrity lock |
| `scripts/`、`tests/` | 安裝、啟動、整合、診斷及驗證；Image 內位於 `/opt/ai-cad/` |
| `.github/workflows/` | 共用建置／測試及 GHCR 發布 |
| `home/`、`workspace/` | 使用者 bind mount 資料，不是專案原始碼 |

不要掃描、清理或覆蓋 `home/`、`workspace/`、`.env`，除非任務明確需要。`home/` 包含帳戶憑證、對話、CAD token 與狀態；完整 Viewer URL 也包含秘密，不可寫入 Git、文件或公開日誌。測試用臨時 HOME/workspace，不借用現有部署資料。

## 必須保留的架構契約

- 啟動鏈：Docker init → root entrypoint 初始化 UID/GID → 降權 → Process Compose。所有常駐服務以映射後的非 root 身分執行。
- Process Compose 只管理 `herdr`、`ovis`、`xvfb`、`cad`。Ovis 等待 Herdr healthy；CAD 等待 Xvfb healthy。Agent sessions 由 Herdr 管理，不是獨立的受監管服務。
- Herdr 使用前景 `hc serve`。不要以 `hc server start/restart` 管理服務；部分 hc CLI（包括 status）會自動啟動 Core。停機 probe 使用 `scripts/check-herdr.py`；保留 Ovis 只連既有 socket 的 transport。
- Process Compose 管理僅走 `/run/ai-cad/process-compose.sock`，不新增管理 TCP port 或 TUI。各服務重試最多 5 次、間隔 5 秒；保留有序停止及故障證據。
- Xvfb 使用 `DISPLAY=:99`，Mesa 使用 `LIBGL_ALWAYS_SOFTWARE=1`。核心建模、STEP/STL 匯出與 PNG 截圖應可在預裝環境離線完成；不引入 Host GPU 依賴或 runtime 自動下載。
- `/opt` 放固定程式與依賴；`/home/agent`、`/workspace` 持久化。不要遞迴 chown 掛載目錄；權限錯誤應明確失敗。
- 對外僅 Ovis 7317、CAD 3245。保留各自的 token 認證及 CAD 的 Host/Origin/cookie 防護，不以移除認證解決 LAN 存取。
- 這是可信任 LAN 的部署。現有 `sudo chown` 授權可能擴大到 root，屬已記錄的權限選擇；不要默默變更。不得新增 privileged、Host Docker socket 或整個 Host HOME 掛載。

## 修改與升版規則

- 沿用 Bash／Python 小腳本及既有設定；避免為簡單整合新增框架、常駐服務或額外抽象。Shell 腳本沿用 `set -euo pipefail`。
- 所有依賴固定版本；保留 checksums、integrity、hash lock、Debian snapshot 與停用自動更新的設定。不要使用浮動 latest 取代建置 pin。
- 查新版不等於升級：以官方 release／registry 比較 repository pin，回報來源及相容風險；未要求升級時，不更新依賴或重啟部署。
- 工具升級同步檢查 `versions.env`、安裝 URL/checksum、Dockerfile 及相關文件。Ovis 需同步 release version、source commit 與 PTY binary checksum。
- Agent 升級同步修改 `agents/package.json`、npm lock 與 `versions.env`。使用 npm 產生 lock，不手改 integrity；Image 仍用 `npm ci --omit=dev`。
- CAD 升級需讓 `cad[build123d]`、`cad-server`、`cad-mcp` 同版，更新 `requirements.in`／`versions.env`，以相容的容器環境執行 `uv pip compile requirements.in --generate-hashes -o requirements.lock`。避免連帶升級無關依賴；安裝保留 `--require-hashes`。
- `scripts/patch-cad-host.py` 是版本限定、原文唯一匹配的上游修補。升 CAD 時重新檢查上游是否已支援前景 `--host`；仍需修補才更新它。不要只放寬版本 assert 或忽略不匹配。
- CAD skills/plugin 隨 Image 內的 CAD release 提供，由 `scripts/setup-cad-agents.sh` 離線設定。Codex／Claude Code 安裝官方 plugin；OpenCode／Pi／Oh My Pi 連結同版 skills，不為同一 Agent 重複安裝兩種整合。Claude plugin 為 skills-only，使用預裝 CAD CLI，不應假定存在 Claude MCP manifest。
- Codex MCP 使用 `/opt/cad/bin/cad-mcp`，不改回啟動時下載的 uvx。setup 必須可重複執行，保留既有使用者 skills；只清理由本專案指向官方已退休 skill 的失效連結。
- 行為或依賴變更時更新 README／相關 docs；架構取捨寫入 `docs/decisions.md`，實測命令、結果與未驗證項目寫入 `docs/acceptance.md`。

## 驗證方式

在 repository 根目錄執行 Host 命令，不要求 Host 安裝 CAD 或 npm 依賴。

Compose 靜態驗證（不輸出實際 token）：

```bash
HOST_UID=12345 HOST_GID=12346 OVIS_TOKEN=ci-only docker compose config --quiet
```

Image／服務／依賴整合變更的主要驗證：

```bash
docker build -t ai-cad-workspace:test .
bash tests/test-container.sh ai-cad-workspace:test
TEST_UID=23456 TEST_GID=23457 bash tests/test-container.sh ai-cad-workspace:test
```

整合測試建立獨立掛載目錄與容器，涵蓋設定、UID/GID、skills discovery、Viewer 認證、Ovis terminal、CAD 幾何／匯出／渲染、四服務恢復、停止與重建持久化；結束會印出證據目錄。

已有運行中的開發容器時，可依變更範圍選最小檢查；以下命令會在其掛載資料中設定整合或建立 smoke 產物，不要對現有部署擅自執行：

```bash
# 容器內命令一律顯式使用映射後的非 root 身分。
docker compose exec --user "$(id -u):$(id -g)" ai-cad /opt/ai-cad/tests/test-config.sh
docker compose exec --user "$(id -u):$(id -g)" ai-cad /opt/ai-cad/scripts/setup-cad-agents.sh
docker compose exec --user "$(id -u):$(id -g)" ai-cad python /opt/ai-cad/tests/check-pi-skills.py
docker compose exec --user "$(id -u):$(id -g)" ai-cad /opt/ai-cad/scripts/smoke-cad.sh
```

- `test-config.sh` 包含固定 schema 驗證、重試上限測試、Process Compose dry-run 與 ShellCheck。
- CAD 或渲染變更不能只看 HTTP healthy；需實際建模、匯出、snapshot，並檢視 PNG。
- 文件修改只需核對路徑、命令與實作一致，不必為此重建 Image。
- 個人登入、真實 LLM 呼叫、跨機 LAN 操作與對話恢復不是 CI 已驗證項目。交付時區分本次實測、歷史紀錄與未測項目。

## 發布與部署

- CI／Release 必須測試並發布同一份 Image；不要測完再重建另一份發布。
- GitHub Actions 固定 commit SHA。只發布已驗證的 amd64；`main` 不更新 `latest`，穩定 `vX.Y.Z` 才更新 `latest` 與 `vX.Y`。
- 不在未要求時 pull／升級現有部署、重建容器或執行 Agent plugin setup。
- 部署升級前停止容器，備份 `home/`／`workspace/` 並記錄 image digest。回滾需恢復舊 Image 及升級前資料，不能假設上游狀態支援降版。
