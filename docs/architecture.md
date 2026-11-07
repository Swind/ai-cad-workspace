# Architecture

```text
Docker init (PID 1)
└─ entrypoint: minimal root UID/GID initialization → gosu
   └─ Process Compose (host UID:GID, foreground, Unix socket)
      ├─ Xvfb :99 / Mesa software GLX
      │  └─ [readiness dependency] CAD Engine :3245
      └─ hc serve
         └─ [readiness dependency] Ovis :7317
```

依賴是啟動順序，不代表 CAD/Ovis 是對應服務的 Linux 子程序。各自為 PC 的 child；hc 自行管理 terminal holder 與 Agent。四個服務均有 readiness/liveness 與有限重啟策略。

`/opt` 保存程式，`/home/agent` 保存持久化狀態，`/workspace` 保存模型產物。`/run/ai-cad` 的 PC socket 與 CAD runtime coordination 每次容器建立重新產生；hc 自己的持久化檔案保留在 HOME。

Xvfb 不開 TCP；PC 只開 UDS，CAD/Ovis 開 0.0.0.0。Docker 僅發布 7317、3245。沒有 Host docker socket、GUI desktop、systemd 或 Supervisord。
