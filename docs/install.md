# 安裝

完整部署、`.env` 生成、UID/GID、GHCR 私有 package 認證與初次 Agent 登入，見 [README](../README.md#部署)。

首次使用請先以 Host 使用者建立 `home`、`workspace`。Compose 使用 `create_host_path: false`，避免 Docker root 代建錯誤所有權的目錄。

建議至少 4 GB RAM，CAD 與多 Agent 同時執行建議 8 GB 以上；Image 包含 OCCT、Mesa、三款 CLI 與 Web build，請預留數 GB image／cache 空間。目前只驗證 Linux amd64。
