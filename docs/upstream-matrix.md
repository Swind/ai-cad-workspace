# 上游版本與驗證來源

版本查詢：2026-11-07。執行結果另見 acceptance.md。

| 元件 | Pin | 來源／命令 |
|---|---|---|
| Process Compose | v1.124.0 | https://github.com/F1bonacc1/process-compose/tree/v1.124.0；`process-compose version`、`--dry-run`、`-t=false -U --ordered-shutdown up` |
| hc | 0.1.18 | https://releases.herdr.dev/core/0.1.18/manifest.json；`hc serve`、`hc server status --json` |
| Ovis | v0.5.0 / 347a989d1c2c71ab273c1a6d9c900054568f97b8 | https://github.com/devswha/ovis/blob/v0.5.0/INSTALL.md；`bun install --frozen-lockfile`、`bun run build`、`bun run server/index.ts` |
| text-to-cad | v0.11.1（2026-11-08 更新） | https://github.com/earthtojake/text-to-cad/tree/v0.11.1；`cad server --port 3245`（本 Image 加 --host 修補）、`cad run`、`cad xbf snapshot`、`cad xbf export` |
| Bun | 1.4.4 | https://github.com/oven-sh/bun/releases/tag/bun-v1.4.4 |
| uv | 0.13.7 | https://github.com/astral-sh/uv/releases/tag/0.13.7 |
| Python | 3.14.0 | Docker official python slim-bookworm，Dockerfile 固定 digest |
| Node | 22.21.1 | Docker official node bookworm-slim，Dockerfile 固定 digest |
| OpenCode | 2.2.6 / @opencode/cli | https://opencode.ai/v2/docs/；官方 npm 安裝方式 |
| Codex | 0.167.0 / @openai/codex | https://github.com/openai/codex/releases/tag/rust-v0.167.0 |
| Claude Code | 2.1.311 / @anthropic-ai/claude-code | https://code.claude.com/docs/en/setup；查詢時 stable channel |
| Pi | 1.5.0 / @earendil-works/pi-coding-agent | https://pi.dev/docs/latest/quickstart；`pi` |
| Oh My Pi | 18.18.1 / @oh-my-pi/pi-coding-agent | https://github.com/can1357/oh-my-pi；Bun 執行 `omp` |

二進位下載的 SHA256 在 versions.env；Python 全部遞迴依賴固定於 requirements.lock；五款 Agent 使用 agents/package-lock.json。Ovis 使用固定 commit 的 bun.lock。PC schema 與 Apache-2.0 license 保存在 config/vendor。

GitHub Actions 使用查詢當日官方 release 的 commit SHA，見 workflow 中的版本註解。只發布 amd64，沒有宣稱 arm64 已驗證。
