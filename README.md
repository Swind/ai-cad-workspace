# AI CAD Workspace

一個 Linux amd64 Container，使用 Process Compose 管理 Xvfb、Herdr Core、Ovis 與 text-to-cad。預裝 OpenCode、Codex、Claude Code；Host 只需要 Docker Engine 與 Compose。

## 目的

把 AI Agent、瀏覽器工作介面、CAD 核心與無螢幕渲染環境封裝成可部署的工作站：

- 在 Ovis 的瀏覽器終端中操作 Agent，於共同的 `/workspace` 編寫與執行 CAD 模型。
- 用 text-to-cad 產生模型、STEP/STL 與預覽圖片，透過 CAD Viewer 檢視結果。
- 程式與依賴隨 Image 固定，模型、認證與對話留在 Host 掛載目錄，方便重建與備份。
- 透過 GitHub Actions 建置、驗證並發布 GHCR Image，Host 不必安裝 Python、Node 或 CAD 工具。

適合個人或可信任 LAN 使用；這不是多使用者隔離平台。Agent 使用的 LLM 帳戶／API 需自行設定，Image 不包含模型服務或登入憑證。

## 架構

```text
Host / LAN 瀏覽器
  ├─ :7317 → Ovis（工作介面／終端）→ Herdr Core → Agent sessions
  └─ :3245 → text-to-cad（CAD Engine／Viewer）

單一 Docker Container
  Docker init → entrypoint（UID/GID 初始化、降權）→ Process Compose
    ├─ herdr：hc serve
    ├─ ovis ：等待 herdr healthy
    ├─ xvfb ：虛擬顯示 :99 + Mesa software OpenGL
    └─ cad  ：等待 xvfb healthy

  /opt         程式、CAD kernel、固定版本依賴
  /home/agent  ← ./home       認證、對話、設定、狀態與 cache
  /workspace   ← ./workspace  模型原始碼及產物
```

| 元件 | 職責 |
| --- | --- |
| Process Compose | 四個常駐服務的啟動依賴、健康檢查、有限重試與有序停止；管理介面僅使用 Unix socket |
| Herdr Core（`hc`） | 管理終端與 Agent sessions；個別 Agent 不註冊成 Process Compose 服務 |
| Ovis | 瀏覽器工作介面，透過既有 hc socket 操作終端 |
| text-to-cad | 建模執行、CAD Viewer、匯出與截圖，MCP 供 Agent plugin 使用 |
| Xvfb／Mesa | 無實體螢幕、無 GPU 的 OpenGL 渲染環境 |
| OpenCode／Codex／Claude Code | 預裝的三款互動式 coding agents，共用持久化 HOME 與 workspace |

CAD 前景 CLI 使用限於 `0.11.1` 的小幅 `--host` 修補，直接監聽 `0.0.0.0:3245`；原有 token 認證保留。實作理由見 [決策紀錄](docs/decisions.md)。

## 部署

### 1. 準備 Host

- Linux amd64、Docker Engine 與 Docker Compose plugin（`docker compose`）。
- 使用有 Docker 權限的非 root Host 使用者執行下列命令。
- 建議至少 4 GB RAM；多 Agent 同時使用建議 8 GB 以上，另預留數 GB Image／cache 空間。
- 首次拉取 Image、Agent 登入與雲端 LLM 呼叫需要網路；預裝的核心 CAD 流程已通過斷網測試。

### 2. 建立目錄與設定

```bash
git clone https://github.com/Swind/ai-cad-workspace.git
cd ai-cad-workspace
mkdir -p home workspace

# 不覆蓋已有設定；以權限 600 建立 .env。
if [ ! -e .env ]; then (
  umask 077
  token=$(docker run --rm --entrypoint python python:3.14.0-slim-bookworm \
    -c 'import secrets; print(secrets.token_hex(32))'
  ) || exit 1
  {
    printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)"
    printf 'IMAGE=ghcr.io/swind/ai-cad-workspace:main\n'
    printf 'OVIS_TOKEN=%s\n' "$token"
    printf 'OVIS_BIND_IP=0.0.0.0\nCAD_BIND_IP=0.0.0.0\n'
  } > .env
); fi
```

也可以複製 `.env.example` 後手動編輯；必須換掉範例 token，UID/GID 使用 Host 的 `id -u`／`id -g`。Compose 不會自動建立掛載目錄，請先完成 `mkdir`。

### 3. 拉取並啟動

```bash
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f
```

等待容器顯示 `healthy`。`logs -f` 可用 Ctrl+C 離開，容器仍在背景執行。若 GHCR package 為 private，先使用有讀取權限的帳戶 `docker login ghcr.io`。

Ovis：`http://<host-ip>:7317`，使用 `.env` 的 token 認證。CAD Viewer：`http://<host-ip>:3245`，模型連結須保留 CAD 自己產生的認證資訊，見下方。

### 從原始碼建置

在 `.env` 將 `IMAGE` 改為 `ai-cad-workspace:local`，然後執行：

```bash
docker compose build
docker compose up -d --pull never
```

## 設定方式

`.env` 由 Compose 讀取；修改後執行 `docker compose up -d` 套用。

| 設定 | 必填／預設 | 說明 |
| --- | --- | --- |
| `HOST_UID` | 必填 | Host 使用者 UID；映射為容器 `PUID`，必須為正整數且非 root |
| `HOST_GID` | 必填 | Host 群組 GID；映射為容器 `PGID`，必須為正整數 |
| `IMAGE` | `ghcr.io/swind/ai-cad-workspace:main` | 可使用 tag 或 `ghcr.io/swind/ai-cad-workspace@sha256:…` 固定 digest |
| `OVIS_TOKEN` | 必填 | Ovis 認證 token；與 CAD Viewer 自行產生的 token 不同 |
| `OVIS_BIND_IP` | `0.0.0.0` | Host 發布 7317 port 的介面；`127.0.0.1` 限本機存取 |
| `CAD_BIND_IP` | `0.0.0.0` | Host 發布 3245 port 的介面；可指定 Host LAN IP |

Host port 目前固定為 7317／3245。若有衝突，修改 `compose.yaml` 的 `ports` 左側 Host port，右側容器 port 保持不變；產生 CAD 連結時傳入實際 `host:port`。

`DISPLAY=:99`、`LIBGL_ALWAYS_SOFTWARE=1` 等 runtime 設定已寫入 Dockerfile。服務參數與重試策略在 `config/process-compose.yaml`；修改 Image 內的檔案後需重新建置。

Provider API Key 若需傳入容器，請在 Compose 的 `environment` 明確加入該 Provider 官方變數；只寫進 `.env` 不會自動傳入容器。互動式登入則依下一節操作，認證保留於 `./home`。

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

Image 已依 text-to-cad v0.11.1 預裝 Python 3.14、uv、`cad-server`、`cad-mcp`、
`cad[build123d]`（含 OpenCascade/OCP），以及 Xvfb、Mesa software OpenGL、X11 libraries 與字型。
核心與 kernel 同在 `/opt/cad`，首次建模、STEP/STL 匯出及 PNG 截圖不用再下載環境。
另預裝官方 `dfm`／`dfam-check` 的 trimesh、NumPy、Rtree、SciPy、NetworkX、lxml，
版本與 hashes 固定在 `requirements.lock`。OrcaSlicer 切片及印表機整合屬額外工具，未包含；
模型自行宣告的其他 Python 套件仍可能需要網路安裝。

```bash
# 容器 shell
/opt/ai-cad/scripts/smoke-cad.sh
cad run /workspace/my-model.py
cad xbf snapshot /workspace/my-model.xbf /workspace/iso.png --camera iso
cad xbf export /workspace/my-model.xbf /workspace/model.step /workspace/model.stl
python /opt/ai-cad/scripts/cad-link.py <host-ip> /workspace/my-model.xbf
```

最後一個命令印出帶認證的 LAN URL，只替換 authority，保留路徑與 token。請不要把完整連結貼入公開日誌。

`my-model.py` 是你建立的模型；輸出的 `.xbf` 檔名由模型決定，請以 `cad run` 的實際輸出替換範例路徑。第一次驗證環境可只執行 `smoke-cad.sh`，它會自動建立測試模型與產物。

## Process Compose 管理

### 修復檔案所有權

`agent` 可免密碼執行 `sudo chown`，適用於動態映射後的 UID/GID。例如在容器終端：

```bash
sudo chown "$(id -u):$(id -g)" /tmp/opencode
```

啟動腳本也會自動將 `/tmp/opencode` 設為 agent 所有。這項 sudo 授權允許任意 chown 參數，
可改動容器系統檔案，以及 Host 掛載的 `home`／`workspace` 所有權，具有擴大至 root 權限的風險。
因此 Compose 未啟用 `no-new-privileges`；此部署僅適用於可信任的使用者與 Agent 工作負載。
改動 Dockerfile／Compose 後需重建 Image 並重建容器，單純 restart 不會套用。

### 服務操作

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

以下在非 root 容器 shell 執行：

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

注意：上游 hc 的 CLI（含 `server status`）可能在 Core 不存在時自動啟動背景程序。因此停機診斷請用 `python /opt/ai-cad/scripts/check-herdr.py`；啟動／重啟一律使用 Process Compose，不用 `hc server start/restart`。上述 `hc server status` 僅供 Core 已健康時查看詳細資訊。

## 掛載、升級與回滾

- `./workspace:/workspace`：模型原始碼、STEP、STL、PNG。
- `./home:/home/agent`：Agent 認證／對話、hc/Ovis 狀態、CAD token／registry／cache。備份時視為秘密資料。
- `PUID/PGID` 部署時設定，Image 不固定為 Host 1000。啟動不遞迴 chown 掛載目錄；權限不符會退出。
- 一般 Linux Docker bind mount 支援 UID/GID 對應；rootless Docker、userns-remap、NFS/ACL 需自行配置映射。

升級前停止容器，備份兩個掛載目錄並記錄當前 image digest；將 `.env` 的 `IMAGE` 設為新版本 digest，執行 `docker compose pull && docker compose up -d`，再執行 doctor／smoke test。回滾需停止容器，還原舊 digest 與升級前的 **home/workspace 備份**；上游狀態格式可能只支援向前遷移。

此環境限可信任 LAN。不掛載 Host Docker Socket 或整個 Home，不使用 privileged。LAN HTTP 上的 token 未加密；若網路不可信應部署 TLS 入口。

Host 上常用的生命週期命令：

```bash
docker compose stop       # 正常停止，保留容器與資料
docker compose start      # 啟動已停止的容器
docker compose down       # 移除容器與 network，保留 home/workspace
```

## Repository 結構

| 路徑 | 內容 |
| --- | --- |
| `Dockerfile`、`versions.env` | Image 建置、runtime 與工具版本／checksums |
| `compose.yaml`、`.env.example` | Host 部署、ports、掛載與設定範例 |
| `config/` | Process Compose、Debian snapshot、OpenCode 設定及 schema |
| `requirements.in`、`requirements.lock` | Python 依賴與完整 hash lock |
| `agents/` | 三款 Agent 的 npm dependencies／lock |
| `scripts/` | 安裝、啟動、健康檢查、Agent plugin 設定及 CAD smoke test |
| `tests/` | 幾何、渲染、Viewer 認證、服務恢復與持久化測試 |
| `.github/workflows/` | CI、Release 與共用建置／發布流程 |
| `docs/` | 架構、安裝、操作、上游版本、決策與驗收紀錄 |

## 測試與發布

```bash
docker build -t ai-cad-workspace:test .
bash tests/test-container.sh ai-cad-workspace:test
TEST_UID=23456 TEST_GID=23457 bash tests/test-container.sh ai-cad-workspace:test
```

PR/main 執行 CI；main、`v*` tag 與手動 Release workflow 發布 GHCR。Release 在本身 workflow 內測試**同一份 Image**再 push。`main` 不更新 `latest`；只有穩定 `vX.Y.Z` 更新 `latest` 與 `vX.Y`。digest 與 smoke PNG 在 Actions artifacts／summary。

版本與取捨：[上游矩陣](docs/upstream-matrix.md)、[決策](docs/decisions.md)。實際驗收狀態以 [驗收紀錄](docs/acceptance.md) 為準。
