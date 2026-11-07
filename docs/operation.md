# 操作

日常命令與除錯見 [README](../README.md#process-compose-管理)。

## 備份與回滾

1. `docker compose stop`，避免備份正在寫入的對話資料庫。
2. 記錄目前 `.env` 的 image digest，以及 `docker image inspect` 的 RepoDigests。
3. 將 `home` 與 `workspace` 一起備份至限制存取的位置；home 含認證。
4. 修改 `IMAGE` 為新 digest，`docker compose pull && docker compose up -d`。
5. 執行 healthcheck、doctor、CAD smoke test；人工確認 Agent resume。
6. 回滾時先停止容器，換回舊 digest 並還原相對應的兩個目錄備份，再啟動。

不能只切換舊 Image 就保證可以讀取升級後的狀態；上游可能做不可逆的狀態格式遷移。

## 服務故障

- `process-compose -U process get <name> -o json`：status、pid、restarts、readiness。
- `process-compose -U process logs <name> --tail 100`：個別服務輸出。
- `/run/ai-cad/supervisor.log`：排程、probe、restart 原因；需在刪除容器前保留。
- 服務重試耗盡：先排除具體錯誤，再 `process-compose -U process restart <name>`。
- 權限初始化失敗：確認 `.env` 與 Host 的 `id -u` / `id -g` 一致，檢查掛載目錄所有權／ACL。不要用 Container 對整個 workspace 遞迴 chown。

`docker compose down` 只移除容器／network，bind mount 仍存在。不要刪除 `home` 來修復一般服務問題。
