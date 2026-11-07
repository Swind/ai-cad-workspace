# 驗收紀錄

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
| 持久化 | PASS，workspace 與 HOME marker、hc keep terminal 記錄保留並恢復為新 shell |

初期失敗與修正：

- 非 root PC 重新開啟 `/dev/stderr` 被拒絕：內部排程日誌改為 `/run/ai-cad/supervisor.log`；服務輸出仍經 PC 前景模式輸出至 Docker logs。
- CAD 未帶 token 的 `/` 回 403：probe 改用本機持久化 token，且不將 token 放進 argv／日誌。
- PC `process get -o json` 回傳陣列：測試改讀 `.[0].pid`。
- hc status 的 autostart 搶管理權：改為 direct socket probe + Ovis 既有 socket transport，故障測試通過。
- Rust PTY binary 已安裝但 Ovis 缺 release metadata 而回退 Node：明確設定 `OVIS_PTY_SIDECAR_BIN`。

## 發布

GitHub Actions / GHCR 尚待執行，未宣稱已發布。Debian snapshot 固定後的最後建置及整合測試正在執行。

## 人工驗收

各 Agent 個人登入與真實雲端 LLM 對話；另一台 LAN 電腦的 Viewer 旋轉／縮放／重建刷新；瀏覽器 Pane disconnect/reconnect 與對話 resume。CI 不假裝這些已通過。
