# 驗收紀錄

## text-to-cad 0.11.1 升級（2026-11-08）

- 上游 tag v0.11.1，commit `4ad86d6`；三個 CAD 套件固定為 0.11.1。
- 本機 Image `ai-cad-workspace:cad-0.11.1` 建置成功。
- UID/GID 23456:23457 的完整 container 整合測試 PASS（CAD 幾何、匯出、截圖、Viewer 認證、Ovis terminal、四服務恢復、sudo chown、停止與重建）。
- 全新 HOME、非 root、`--network none` 的 CAD smoke test PASS。
- 新版 setup 的離線重複執行、官方退休 skill 失效連結移除、其他來源失效連結保留均 PASS。
- 現有部署已切換本機新版並 healthy；掛載資料上的新版 setup 與 smoke test PASS。Codex／Claude plugin 均為 0.11.1，OpenCode 使用新版六個 skills。
- 升級前 HOME／workspace 與 .env 已備份至 Host 的 `~/ai-cad-backups/`；未執行還原演練。
- 此版本 GHCR 發布結果待 Actions 確認；本機已部署，不依賴該次發布完成。

施工中；尚未標記 Done。機械化整合測試已通過，GHCR 與人工驗收狀態見下方。

## 已執行

- `docker version`：Linux amd64，Docker client/server 29.6.2 可用。
- `git ls-remote git@github.com:Swind/ai-cad-workspace.git`：成功，空 repository。
- 上游 clone/tag checkout、GitHub release API、hc manifest：成功。
- Process Compose 1.124.0 二進位 `--help`、`process get/logs --help`：成功。
- `herdr-core serve --help`：成功，前景入口存在。
- `process-compose -f config/process-compose.yaml --dry-run`：四服務配置解析成功。
- Docker pull Python/Node 固定 image：成功，digest 已寫入 Dockerfile。
- 容器內 `uv pip compile requirements.in --generate-hashes -o requirements.lock`：成功。
- 容器內 `npm install --package-lock-only --ignore-scripts`：成功，audit 0 vulnerabilities。

## 本機整合測試（2026-11-07）

`docker build --progress=plain -t ai-cad-workspace:test .` 成功。

`bash tests/test-container.sh ai-cad-workspace:test` 與
`TEST_UID=23456 TEST_GID=23457 bash tests/test-container.sh ai-cad-workspace:test` 均成功。

| 測試 | 結果 |
|---|---|
| PC 官方 JSON Schema、native dry-run、ShellCheck、Compose config | PASS |
| PC 永久故障的有限重試（initial + 2 retries） | PASS，第三次結束後停止重試；獨立測試專案退出碼為 0，故監控不可只看 PC 退出碼 |
| UID:GID 1000:1000 與 23456:23457 | PASS，服務 PID 與 workspace 新檔案 ownership 一致 |
| Xvfb + Mesa | PASS，llvmpipe software renderer，GLX OpenGL 4.5，無 GPU |
| hc、Ovis、CAD readiness | PASS |
| 三款 Agent version | PASS：OpenCode 2.2.6、Codex 0.167.0、Claude 2.1.311 |
| Codex / Claude CAD plugin listing | PASS，0.10.4；OpenCode skills symlink 成功 |
| Ovis API 建立真實 hc Pane、執行 Codex CLI、HTTP 重連讀回 | PASS |
| CAD LAN Host / Origin / token / session cookie | PASS；未認證與跨站 cookie 請求回 403，正確認證回 200 |
| 80×50×5 板與中央 Ø6 通孔 | PASS，STEP 重新讀入，Solid validity/count、bounds、volume、厚度方向取樣 |
| STEP/STL、top/iso PNG | PASS，800×600；非空白像素檢查通過，iso 已人工檢視圖片 |
| kill -KILL 各服務 | PASS，四個服務由 PC 重啟，PID 更換，health 恢復 |
| 故障恢復後再次建模／渲染 | PASS |
| docker stop、recreate | PASS，非 137 退出、PID=0；新容器 health 恢復 |
| Process Compose 原生 restart、Docker SIGINT | PASS，單服務手動重啟恢復、SIGINT 在 60 秒內結束 |
| 持久化 | PASS，workspace 與 HOME marker、hc keep terminal 記錄保留並恢復為新 shell |

初期失敗與修正：

- 非 root PC 重新開啟 `/dev/stderr` 被拒絕：內部排程日誌改為 `/run/ai-cad/supervisor.log`；服務輸出仍經 PC 前景模式輸出至 Docker logs。
- CAD 未帶 token 的 `/` 回 403：probe 改用本機持久化 token，且不將 token 放進 argv／日誌。
- PC `process get -o json` 回傳陣列：測試改讀 `.[0].pid`。
- hc status 的 autostart 搶管理權：改為 direct socket probe + Ovis 既有 socket transport，故障測試通過。
- Rust PTY binary 已安裝但 Ovis 缺 release metadata 而回退 Node：明確設定 `OVIS_PTY_SIDECAR_BIN`。

## 發布

補充：CI #2（42385097802）與 Release #2（42385097676）已確認 Success；此結果對應補充 mesh 依賴前的版本。

## text-to-cad 環境補充驗證（2026-11-07）

- 對照上游 v0.10.4 `docs/install.md` 與 `skills/{dfm,dfam-check}/requirements.txt`。
- 原有 Python 3.14、CAD/kernel/MCP、Xvfb、Mesa、X11 與字型已滿足核心流程。
- 補入固定版本 trimesh、Rtree、NetworkX、lxml；NumPy/SciPy 已存在，新增為明確依賴。原有 lock 中的套件版本未變動。
- `docker build -t ai-cad-workspace:cad-env .`：PASS。
- 使用 `docker run --network none --init`、全新 `/tmp/offline-home`、UID/GID 1500:1500 啟動 Xvfb 與 CAD：PASS。
- 該斷網容器執行 `scripts/smoke-cad.sh`：建模、STEP/STL、top/iso PNG 與幾何驗證全部 PASS。
- `tests/check-mesh-deps.py`：mesh split、R-tree ray casting、3MF export/reimport 體積驗證 PASS，納入既有 smoke test。
- OrcaSlicer／實體印表機整合未安裝或測試；任意模型額外宣告的 Python 依賴不在離線保證內。

### 前一版發布紀錄

Debian snapshot 固定後，`docker build -t ai-cad-workspace:verified .` 與
`TEST_UID=23456 TEST_GID=23457 bash tests/test-container.sh ai-cad-workspace:verified` 已成功；本機 Image ID
`sha256:6e24cfeb6e862bd8f0baac838043e0fec4f946414ac312568db386a49edd627c`（此為本機 image ID，不是 GHCR 發布 digest）。

首次程式碼已推送 main：`0135b1fbd5b8b33528a7eea2f6045d431307f170`。
遠端 [CI #1](https://github.com/Swind/ai-cad-workspace/actions/runs/42384586290) 與
[Release #1](https://github.com/Swind/ai-cad-workspace/actions/runs/42384586313) 已啟動，結果尚待確認；未宣稱已發布。

## 人工驗收

各 Agent 個人登入與真實雲端 LLM 對話；另一台 LAN 電腦的 Viewer 旋轉／縮放／重建刷新；瀏覽器 Pane disconnect/reconnect 與對話 resume。CI 不假裝這些已通過。

## 原規格 A01–A12 對照

| ID | 狀態 | 證據／待驗收部分 |
|---|---|---|
| A01 | PASS | 安裝／建模／測試全部在 Docker 執行，沒有在 Host 全域安裝 CAD 或 Agent |
| A02 | PASS | `/proc/<service-pid>` UID/GID、非 root exec id；兩組部署 UID/GID |
| A03 | PASS | Host `stat` 新建 workspace 檔案 UID/GID |
| A04 | PARTIAL | HOME/hc/Ovis 記錄 recreate 後保留；私人 Agent 認證恢復待人工 |
| A05 | PARTIAL | Ovis health 與 published port 通過；另一台電腦瀏覽器待人工 |
| A06 | PARTIAL | 真實 Ovis/hc Pane 與 CLI 執行、跨 HTTP connection 重連通過；真人 LLM 與完整瀏覽器互動待人工 |
| A07 | PARTIAL | 固定 build123d 模型、幾何與輸出通過；由登入後 LLM 自行產生模型待人工 |
| A08 | PARTIAL | LAN Host、Origin、Cookie、token 的 HTTP 測試通過；遠端瀏覽器旋轉縮放待人工 |
| A09 | PASS | stop/recreate 後 Web health、workspace、hc keep 記錄恢復 |
| A10 | PENDING | main/PR workflow 已提交，遠端 run 待確認；尚未建立 PR 事件實測 |
| A11 | PENDING | GHCR run 待確認；不同 UID/GID 本機部署已通過 |
| A12 | PARTIAL | image digest / state 備份回滾流程已寫；尚無第二個應用版本可跨版本實測 |
