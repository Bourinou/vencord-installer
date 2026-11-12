# vencord-installer

Generic Vencord (desktop, built from source) updater: clone/pull, `pnpm install`, plugin hooks, `pnpm build`, `pnpm inject`.

## Windows

Requires `git`, `pnpm`, `node`. Run:

```powershell
.\update-vencord.ps1
```

The Vencord checkout lives in `Vencord/` (gitignored). Plugins hook in via `hooks/`, see [hooks/README.md](hooks/README.md). `orionQuests` ships built in.

## Linux

Coming.
