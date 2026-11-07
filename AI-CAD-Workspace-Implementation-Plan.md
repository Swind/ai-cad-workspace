# AI CAD Workspace — AI Agent 實作規格書

版本：1.0（2026-11-07）  
目標讀者：負責施工的 Coding Agent  
狀態：待實作；下列命令與版本需在施工時以鎖定的上游 Release 驗證。

## 0. 執行指令（交給 Coding Agent）

你是本專案的實作者。請直接建立可部署的 GitHub Repository，完成程式碼、Dockerfile、Compose、GitHub Actions、測試、文件及範例。不得只交付概念或 TODO。依序先調查上游、再做最小可運作 PoC、整合、CI、驗收。每一步必須記錄實際指令與結果。若上游 API/CLI 不相容，依最新穩定 Release 的官方文件修正，將版本與取捨寫在 `docs/decisions.md`；不可臆造指令。除非遇到不可逆的外部授權或必要秘密資訊，應自行完成可獨立進行的工作。不得將登入憑證提交到 Git。

## 1. 背景與目標

打造一個可透過 LAN 瀏覽器使用的、完全容器化的 AI CAD 開發環境。Host 只需 Docker/Compose，不安裝 AI Agent、Ovis、Herdr、FreeCAD、build123d 或 Python CAD Runtime。所有模型原始碼、STEP、STL、PNG 存在 Host 的 Bind Mount，Agent Session 與認證狀態另行持久化。使用者可從 Ovis 操作不同 Coding Agents，並從 CAD Viewer 預覽 CAD。

### 必須達成

1. **單一應用容器**：包含 Agent Runtime、Session Runtime、Ovis、text-to-cad CAD Runtime。可使用 entrypoint/supervisor 啟動多個非特權使用者進程；不依賴 GUI、X11 或 Xvfb。
2. **一致檔案所有權**：Container 內實際執行 Agent/CAD 的 UID:GID 與 Host 當前使用者一致。此值在部署時傳入，**不可在 CI 建置 Image 時綁死為 1000:1000**。
3. **Host 掛載**：`./workspace:/workspace`、`./home:/home/agent`；所有模型、設定、登入資訊與 Session 分別持久化。
4. **LAN 可訪問**：Ovis `7317`；text-to-cad Viewer `3245`，服務須在容器內監聽 `0.0.0.0`；採 Docker `ports` 發布。
5. **至少可用一款 Coding Agent**，優先 Codex；Claude Code 為第二個，OpenCode 可作可選。禁止使用一個假的終端或靜態 UI 代替真實 Agent。
6. **CAD 端到端**：AI 建立 build123d Python、成功重建實體、Snapshot PNG、STEP/STL、從外部瀏覽器開啟 CAD Viewer；有幾何有效性檢查。
7. **CI/CD**：GitHub Actions PR Build/Test；push main 與版本 Tag 發布到 `ghcr.io/<owner>/<repo>`；有 digest、標籤、測試與使用文件。
8. **可重現建置**：固定上游 Release 或 Commit、Runtime 版本與套件鎖檔；不得在 Container 每次啟動時自動更新 Plugin 或盲目下載最新版。
9. **可重啟**：瀏覽器關閉不影響 Agent；容器重啟後可恢復持久化的 Workspace/Conversation 記錄，但不承諾正在執行的 Linux 程序繼續存活。

### 非目標

- 不建置 Kubernetes、不建立多租戶認證平台、不以 FreeCAD GUI 操作 CAD。
- 不提供公開網際網路服務；用途限可信任 LAN。
- 不保證所有幾何檢查可取代實際 3D 列印試裝。
- 不強制製作多架構 Image，除非兩種架構實測均合格。

## 2. 上游選型與施工前核對（P0）

1. **Herdr Runtime**：優先研究並採用無 GUI 的 `herdr-core` (`hc`)；確認 Ovis `OVIS_RUNTIME=herdr-core` 與 `OVIS_HC_BIN` 能在 Docker 中建立/重連 Pane。若關鍵 Agent 工作流程不支援，才改用 Herdr CLI/TUI Server。不可安裝需要 Linux 桌面/Vulkan 的 Herdr Desktop 當容器核心。
2. **Ovis**：對照固定版本 `INSTALL.md`、`docs/guide.md`，查明 Source Checkout、Bun、PTY sidecar、`HOST`、`PORT`、`OVIS_TOKEN`、`OVIS_STATE_DIR` 的實際行為。用 herdr-core 時可採 **source checkout 安裝 Ovis**，無須強制採 `herdr plugin install`；若選 herdr CLI，可使用官方 Plugin 路線。
3. **text-to-cad**：固定穩定版；核對安裝文件與版本相符的 CLI 命令。上游文件存在 `cadgen` 舊接口與 `cad`/`cad-server` 新接口，**不得混用**。調查 CAD Viewer HTTP server 的真實啟動方式、`--host`/`--port`、持久化路徑、CLI、MCP 與 Agent Plugin。
4. **Agent**：Codex、Claude Code 的 CLI 安裝方式，登入/使用 API Key 的方法與 Session 檔案位置；不得在 Docker build 時需要使用者的私人 Token。
5. **環境支援**：優先 Linux amd64；arm64 的 OCCT wheels / Bun / Ovis PTY / Agent binaries 全部確認後才發布 arm64。

建立 `docs/upstream-matrix.md`，每一項附 Source URL、Release tag/commit、實際使用命令、理由與驗證結果。

參考來源：
- https://github.com/herdrdev/herdr-core
- https://github.com/devswha/ovis/blob/main/INSTALL.md
- https://github.com/devswha/ovis/blob/main/docs/guide.md
- https://github.com/earthtojake/text-to-cad/blob/main/docs/install.md
- https://github.com/earthtojake/text-to-cad/blob/main/packages/cad/README.md
- https://github.com/earthtojake/text-to-cad

## 3. 目錄與交付物

```text
ai-cad-workspace/
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── .gitignore
├── .env.example
├── versions.env               # 或 versions.json，記錄所有 pins
├── scripts/
│   ├── entrypoint.sh           # UID/GID 對應及權限檢查
│   ├── start-services.sh       # 非 root 啟動與監測服務
│   ├── healthcheck.sh
│   ├── doctor.sh               # 版本、ports、workspace、CAD 診斷
│   └── smoke-cad.sh
├── tests/
│   ├── test-permissions.sh
│   ├── test-persistence.sh
│   ├── test-ovis.sh
│   └── sample-model.py
├── .github/workflows/
│   ├── ci.yaml
│   └── release.yaml
├── docs/
│   ├── install.md
│   ├── operation.md
│   ├── architecture.md
│   ├── upstream-matrix.md
│   └── decisions.md
├── home/                      # Git ignored; deploy 時建立
└── workspace/                 # Git ignored; deploy 時建立
```

建置文件不得納入 `home/`、`.env`、`workspace/`、秘密或 Session。

## 4. UID/GID 設計（重要）

**問題**：GHCR Image 必須可供不同 UID/GID 的 Host 共用，故不能採 `ARG USER_UID=$(id -u)` 固化於 CI Image。

建議實作：
- Image 內預先建立 `agent` 帳號與 `/home/agent`；啟動時容器 entrypoint 暫時以 root 執行最小初始化：讀取 `PUID`/`PGID`，對 `agent` UID/GID 做安全調整（處理已存在 GID、rootless 或受限 Docker 情況），然後透過 `gosu` 或 `setpriv` 降權，啟動所有長駐服務。不得以 root 長期運作 Agent。
- Compose 以環境變數 `PUID=${HOST_UID}`、`PGID=${HOST_GID}` 傳入；**不要同時用 Compose `user: UID:GID` 導致 root 初始化無法執行**。若採純 `user:` 方案，須解決 passwd/home/權限並在文件說明。
- 不對整個 Bind Mount 遞迴 `chown -R`；啟動時檢查 `home/`、`workspace/` 是否可寫，不符合就給清楚的修復提示。可對容器內自行建立的小範圍目錄調整權限。
- 以 `id -u`/`id -g` 驗證程序身分，以 `stat -c '%u:%g'` 驗證新建檔案的 Host 所有權。
- 明確註明一般 Linux Docker Bind Mount 的行為；rootless Docker、user namespace remap、NFS/ACL 可能需要額外設定。

## 5. Docker 與 Compose

建議基礎映像 `ubuntu:24.04`（可依上游相容性調整），安裝基本 SSL/CLI 工具、`git`、`curl`、`bash`、`ca-certificates`、`gosu`、`tini`/Docker `init: true`、Bun、`uv`、Agent CLI、hc、Ovis、CAD Runtime。安裝於 Image 或固定版本的唯讀系統路徑，不以 `home/` Bind Mount 覆蓋二進位檔與必要套件；`/home/agent` 只保存個人設定/Cache/認證/Session。將程式及依賴保留在 `/opt/...`、`/usr/local/...`，由 `/home/agent` 下的可寫狀態支援。

Compose 參考（Agent 應交付可實際使用的版本）：

```yaml
services:
  ai-cad:
    image: ${IMAGE:-ghcr.io/OWNER/ai-cad-workspace:latest}
    init: true
    restart: unless-stopped
    environment:
      HOME: /home/agent
      PUID: ${HOST_UID}
      PGID: ${HOST_GID}
      HOST: 0.0.0.0
      PORT: '7317'
      OVIS_RUNTIME: herdr-core
      OVIS_AUTO_UPDATE: '0'
      OVIS_TELEMETRY: '0'
      CADGEN_UPDATE_CHECK: '0'
      OVIS_TOKEN: ${OVIS_TOKEN}
    ports:
      - '${OVIS_BIND_IP:-0.0.0.0}:7317:7317'
      - '${CAD_BIND_IP:-0.0.0.0}:3245:3245'
    volumes:
      - ./home:/home/agent
      - ./workspace:/workspace
    working_dir: /workspace
    security_opt:
      - no-new-privileges:true
    # 需在固定上游版本驗證 CAD Viewer 對外監聽設定
```

範例 `.env.example`：

```dotenv
HOST_UID=1000
HOST_GID=1000
IMAGE=ghcr.io/OWNER/ai-cad-workspace:latest
OVIS_TOKEN=replace-with-local-token
OVIS_BIND_IP=0.0.0.0
CAD_BIND_IP=0.0.0.0
```

官方 Ovis 的 source/server 環境變數與 Herdr Plugin config env 的優先序可能不同；正式程式須以已選安裝模式驗證。若 Ovis 的 Plugin 無法接收 Compose 環境變數，應在啟動時以非 root 將必要設定安全寫入 Plugin config-dir 的 `env`，而不是假設會繼承。

## 6. Headless Runtime / 開機流程

優先方案（需 PoC 驗證）：

1. 容器 entrypoint 處理 PUID/PGID、檢查掛載目錄。
2. 降權到 `agent` 後啟動 herdr-core/hc 所需 Session Runtime（查證其 daemon/socket/自動啟動模型）。
3. 啟動 Ovis，固定 `OVIS_RUNTIME=herdr-core`，`HOST=0.0.0.0`，`PORT=7317`，必要時提供 `OVIS_HC_BIN`。
4. 啟動 text-to-cad CAD Server，Viewer 綁定 `0.0.0.0:3245` 且固定 port；若 CAD Engine 以 lazy-start 為設計，建立支援且可監測的初始化方式，不可依賴瀏覽器手動啟動。
5. 使用 init/supervisor 正確轉發 SIGTERM 與回收子程序；重要服務退出時，容器 healthcheck 標示 unhealthy，必要時 supervisor 退出觸發容器 restart。記錄服務輸出到 stdout/stderr。
6. 服務啟動後 `curl` 檢查 Ovis `/api/health`，對 CAD 使用該版本官方支援的 `status`/HTTP 診斷，不以未驗證的 URL 假裝 Health Check。

要求無人登入 GUI 時可自行啟動服務，並且 Docker Restart 後自動恢復可用 Web UI。確保 Ovis 能建立新 Agent Pane 並重連既有 Pane；重啟容器後以可恢復的 Agent 對話紀錄重新開啟工作，不能宣稱原進程永續。

## 7. AI Agent 與 text-to-cad

- 支援至少 Codex CLI；Claude Code 依授權與安裝方式提供可選方案。OpenCode 列為選配，不影響核心驗收。
- 完整 Plugin 與獨立 Skills 不要對**同一個 Agent**重複安裝；以官方對應 Agent 的安裝方式為準。
- 固定 Plugin/Skill release 或 commit，避免 `latest` 漂移。允許 CI 使用受控的 Release 升級 PR。
- 以 `docker compose exec ai-cad ...` 進行首次 Agent 登入或提供 API Key；不把個人認證交給 CI。
- text-to-cad 使用 build123d，提供模型原始 Python 程式、CAD 產出、可供 Browser 開啟的 Viewer；視需要使用 MCP，不需自行開發另一套 CAD API。
- 檢查 CAD 模型 `is_valid`、Solid 數、Bounding Box；產生可檢查的 PNG Snapshot、STEP 與 STL。Python 是參數化設計原始來源，STEP/STL 是交換/製造格式。
- 若 Viewer 產生 `127.0.0.1` 的容器內部連結，必須提供穩定的 LAN URL 重寫或入口顯示方式，確保瀏覽器能連到 Host IP。測試 HTTP Host/Origin/Cookie/Token 的限制，而不是只確認 port listening。

## 8. GitHub Actions / GHCR

### CI (`ci.yaml`)

事件：pull_request；push main。步驟：Checkout → Docker Buildx → ShellCheck 或腳本語法檢查 → Compose config validation → Docker Build → Container Smoke Test →（必要時）PR 不推 Image。

### Release (`release.yaml`)

事件：push main、push `v*` tag、`workflow_dispatch`。建立 GHCR Image：

- `main`：`ghcr.io/<lowercase-owner>/<repo>:main`，可選 `:edge`。
- `vX.Y.Z`：`:vX.Y.Z`、`:vX.Y`，穩定版 Tag 才更新 `:latest`。
- 每個版本輸出 digest `sha256:...`，可供生產部署釘選。
- `permissions: contents: read; packages: write`；使用 `${{ secrets.GITHUB_TOKEN }}` 登入 GHCR。
- 使用 `docker/setup-qemu-action`、`docker/setup-buildx-action`、`docker/login-action`、`docker/metadata-action`、`docker/build-push-action` 官方 Action 的穩定版本；正式提交時依當前官方文件釘選 Action 版本或 Commit SHA。
- 使用 `type=gha` BuildKit cache；以 OCI labels 提供來源 URL、版本、Git SHA。
- 正式發版前跑基本 Smoke Test；建置失敗不可發布 `latest`。
- 預設只輸出 `linux/amd64`，`linux/arm64` 通過所有依賴與 Smoke Tests 後才擴充。不可只因 buildx 能編譯就宣稱 arm64 功能正常。
- README 清楚註明 Private GitHub Repository 的 GHCR Pull 可能需要登入或 Package 可見性調整。

**CI 不能在沒有使用者登入的情況下跑真實雲端 LLM 對話**；應以 CLI `--version`、Plugin listing、Headless Ovis health、CAD 小模型為機械化測試，並將真人登入驗收獨立列為 Manual Acceptance。

## 9. 測試與驗收標準（必須全部通過）

| ID | 驗收項目 | 可量測結果 |
|---|---|---|
| A01 | Host 安裝範圍 | Host 只需 Docker/Compose；未安裝 CAD/Agent 的全域執行依賴 |
| A02 | 身分一致 | `docker exec ... id -u/id -g` 與 HOST_UID/GID 相同 |
| A03 | Bind Mount | 在 `/workspace` 建立檔案後，Host `stat` UID/GID 與使用者一致 |
| A04 | State | `./home` 有 Agent/Herdr 或 hc/Ovis 設定；recreate 後保留登入與可用記錄（不承諾原進程） |
| A05 | Ovis | `curl http://127.0.0.1:7317/api/health` 回應正常，遠端 LAN 瀏覽器可進入 |
| A06 | Session | Ovis 建立真實 Agent Pane、發出命令、關閉瀏覽器後重連仍能看到 Pane |
| A07 | CAD | build123d 範例生成合法 Solid，輸出 STEP/STL/PNG |
| A08 | Viewer | 從 LAN 其他電腦能開啟同一模型；旋轉縮放與重建刷新正常 |
| A09 | Restart | Docker Restart 後 Ovis/CAD 自動啟動；Project/Session 記錄保留 |
| A10 | CI | PR 成功測試，無權向 GHCR 推送正式 tag |
| A11 | GHCR | main/tag 發版可 Pull；Image 可在新 Host 以不同 UID/GID 部署 |
| A12 | 更新 | 改版後重建 Image 可保留既有 `home` 與 `workspace`，有回滾流程 |

CAD Sample：80×50×5 mm 板，中央 Ø6 mm 通孔。透過 build123d/Engine 建模；驗證 Bounding Box、孔位置、Solid 有效性；產生 top/isometric Snapshot 與 STEP/STL。寫獨立測試避免只驗證命令退出碼。

## 10. 施工階段

**P0 — 技術確認**：鎖定上游版本；確認 hc + Ovis headless、CAD Viewer bind、Bun/PTy、Codex；產出 `upstream-matrix.md`。不通過則記錄阻礙與替代方案，不進行錯誤堆疊整合。

**P1 — 最小 Docker PoC**：Image 啟動非 root Agent、匹配 UID/GID、Bind Mount、Ovis health。先不做 GHCR。

**P2 — CAD 整合**：安裝固定版本 text-to-cad，驗證建模 → 截圖 → Viewer → STEP/STL，實測 LAN Link。

**P3 — Session / UX**：Ovis 建立 Codex Pane；Browser Disconnect/Reconnect；Container Restart 後 Workspace 與 Agent Session Restore 文件。

**P4 — CI/CD**：PR 測試、main/tag 發 GHCR、Cache、labels、digest、release notes。

**P5 — 文件與交付**：提供 `.env.example`、操作手冊、診斷方式、備份還原與版本升級說明；完成 A01–A12 測試表，附實測結果。

## 11. 操作手冊必須包含

- `mkdir -p home workspace`；以 Host 使用者建立，不能由 Docker root 默默建立到錯誤所有權。
- `HOST_UID=$(id -u)`、`HOST_GID=$(id -g)` 寫入 `.env` 的完整安全程序。
- `docker compose pull && docker compose up -d`；`docker compose logs -f`；`docker compose exec ai-cad sh`。
- 初次 Agent 認證與 Session 可恢復的操作方式；不同 Agent 各自標明。
- LAN URL：`http://<host-ip>:7317`、CAD Viewer 正確帶認證的模型連結；若選擇 Ovis 配對或 token，說明一遍即可。
- 無損升級：備份 `home`/`workspace`、固定 image digest、pull/up、驗證、rollback。
- 偵錯：Ovis health、Herdr/hc runtime、CAD status、Socket、PTY、OpenGL/OCCT headless、Viewer link、檔案權限。
- 明確聲明內網使用，不掛載 Host Docker Socket、整個 Home 或 `--privileged`；此為避免 Host 污染的基本措施，而非要求企業級資安系統。

## 12. 完成定義

只有在所有必需驗收通過、實際 GHCR 產物可被部署、文件完整、沒有未完成的虛構命令時才標記 Done。若需要使用者提供 GitHub Repository 存取權、Secret 或個人 Agent 登入，應先完成全部無需該資訊的工作，再精準報告阻礙與執行者需完成的單一步驟。

最終回報包括：GitHub Repository URL、GHCR Image URL/tag/digest、上游版本清單、開放 Ports、Host 掛載位置、驗收結果、待處理限制。
