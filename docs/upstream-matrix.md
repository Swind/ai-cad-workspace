# 上游版本與驗證來源

版本查詢：2026-11-13；本次更新 CAD、Herdr Core、Ovis、uv 與五款 Agent。其他固定版本維持不變；執行結果另見 acceptance.md。

| 元件 | Pin | 來源／命令 |
|---|---|---|
| Process Compose | v1.124.0 | https://github.com/F1bonacc1/process-compose/tree/v1.124.0；`process-compose version`、`--dry-run`、`-t=false -U --ordered-shutdown up` |
| hc | 0.1.20 | https://releases.herdr.dev/core/latest.json；`hc serve`、direct socket `server.status` probe（避免 CLI status autostart） |
| Ovis | v0.5.3 / 184ac6d47c5c87b0b90c59c32db69cf84d54ee86 | https://github.com/devswha/ovis/blob/v0.5.3/INSTALL.md；`bun install --frozen-lockfile`、`bun run build`、`bun run server/index.ts` |
| text-to-cad | v0.11.9 | https://github.com/earthtojake/text-to-cad/tree/v0.11.9；`cad server --port 3245`（本 Image 加 --host 修補）、`cad run`、`cad xbf snapshot`、`cad xbf export` |
| Bun | 1.4.4 | https://github.com/oven-sh/bun/releases/tag/bun-v1.4.4 |
| uv | 0.13.8 | https://github.com/astral-sh/uv/releases/tag/0.13.8 |
| Python | 3.14.0 | Docker official python slim-bookworm，Dockerfile 固定 digest |
| Node | 22.21.1 | Docker official node bookworm-slim，Dockerfile 固定 digest |
| OpenCode | 2.2.7 / @opencode/cli | https://registry.npmjs.org/@opencode%2Fcli/latest；官方 npm latest |
| Codex | 0.167.2 / @openai/codex | https://registry.npmjs.org/@openai%2Fcodex/latest；官方 npm latest |
| Claude Code | 2.1.322 / @anthropic-ai/claude-code | https://registry.npmjs.org/@anthropic-ai%2Fclaude-code/latest；官方 npm latest |
| Pi | 1.5.2 / @earendil-works/pi-coding-agent | https://registry.npmjs.org/@earendil-works%2Fpi-coding-agent/latest；`pi` |
| Oh My Pi | 18.19.0 / @oh-my-pi/pi-coding-agent | https://registry.npmjs.org/@oh-my-pi%2Fpi-coding-agent/latest；Bun 執行 `omp` |

二進位下載的 SHA256 在 versions.env；Python 全部遞迴依賴固定於 requirements.lock；五款 Agent 使用 agents/package-lock.json。Ovis 使用固定 commit 的 bun.lock。PC schema 與 Apache-2.0 license 保存在 config/vendor。

GitHub Actions 使用查詢當日官方 release 的 commit SHA，見 workflow 中的版本註解。只發布 amd64，沒有宣稱 arm64 已驗證。
