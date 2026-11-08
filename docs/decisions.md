# 實作決策

## 2026-11-08：Agent chown 授權

使用者選擇允許 `agent` 免密碼執行任意 `/usr/bin/chown`。Image 安裝 sudo，
`config/agent-sudoers` 依使用者名稱授權以相容動態 UID/GID；Compose 與整合測試移除
`no-new-privileges`，使 sudo 可提權。任意 root chown 可影響系統及 bind mount，
並可能間接取得完整 root 權限，此為使用者選擇的權限模型。
入口初始化同時修復 `/tmp/opencode` 的目錄 owner（不遞迴），避免建置時 root 建立的目錄阻擋 Agent。
本機 `ai-cad-workspace:chown` 建置與 UID/GID 23456:23457 的完整整合測試通過。

## 2026-11-07

1. 新目錄最初只有規格書；遠端 `git@github.com:Swind/ai-cad-workspace.git` 為空，初始化 main。尚未存在可沿用的部署程式。
2. 使用者補充的 Xvfb 要求取代原規格「不使用 Xvfb」。採 Xvfb + Mesa software GLX，不使用 Host GPU。
3. Base 改用 Python 3.14.0 / Debian bookworm（digest pinned），滿足 text-to-cad 0.10.4 的 Python 3.14 要求。Node 22.21.1 與 Dockerfile frontend 同樣固定 digest。apt 使用 Debian / Debian security 的 `20261107T000000Z` snapshot，應用依賴有 hash lock；固定依賴不等於保證整個 OCI 產物 bit-for-bit 相同。
4. Process Compose 1.124.0 使用前景、非 TUI、UDS 管理。Docker `init: true` 提供 PID 1 回收。只有 PC 管理常駐服務，hc 管理 Agent sessions。
5. hc 0.1.18 的 `hc serve` 是上游內建（一般 help 隱藏）的前景入口，已驗證 `hc serve --help`。`hc server start` 會背景化，不能拿它當前景受監管程序。**實測發現 `hc server status` 也會 autostart**，故 probe 使用官方 `server.status` JSON-RPC socket API。Ovis 的 `hc connect` 以只連接既有 socket 的透明 stdio transport 取代，防止 crash 後 Ovis 搶先啟動不受 PC 管理的 Core；其餘 hc 指令保留原版。`HC_SOCKET` 明確設為 `/run/ai-cad/hc.sock`。
6. Ovis 0.5.0 以 source commit + frozen Bun lock 建置，release PTY binary checksum 驗證；執行 `bun run server/index.ts`，避免 runtime build／managed updater。
7. **CAD --host 修補經使用者確認採用**：0.10.4 的 `cad server` 前景預設 loopback、未提供 --host；`cad viewer --host` 是啟動後退出的 launcher。socat 無法解決 loopback Host gate（LAN Host 會 403）。使用者在確認此限制後選擇小幅修補，故最後不安裝 socat／Nginx。
8. 修補僅修改 `cad_server/engine/cli.py`、`daemon.py` 共四處，為前景 server 傳遞 host。預設維持 loopback。`scripts/patch-cad-host.py` 驗證 0.10.4 與每一處唯一原文，升版時不匹配即 build fail。沒有移除 token 或改寫 auth gates；上游非 loopback bind 本來就允許 LAN Host。
9. CAD library、server、kernel 在 `/opt/cad` 同一個鎖定環境；上游自動辨識 kernel 已存在，不在啟動時下載依賴。模型額外要求的新套件不在此承諾內。
10. 使用者要求三款 Agent 全部預裝：OpenCode V2 2.2.6、Codex 0.167.0、Claude Code stable 2.1.311。透過固定 npm dependencies + integrity lock 安裝至 `/opt/agents`。OpenCode 的 `/etc/opencode/opencode.json` 設定 `update: disable`；Claude Code 設定 `DISABLE_UPDATES=1`。
11. 有限次 crash restart：5 次、5 秒 backoff，耗盡後保留 degraded 狀態供診斷；不讓 Docker restart policy 造成無限靜默重試。正常 SIGTERM 使用反向依賴停止。
12. 不承諾 Container restart 後 Linux 程序繼續運作。hc keep 的恢復為新 shell；Agent 對話由各 Agent 自己的持久化機制 resume。
