# vencord-installer

Generic Vencord (desktop, built from source) updater: clone/pull, `pnpm install`, plugin hooks, `pnpm build`, `pnpm inject`.

## Windows

Requires `git`, `pnpm`, `node`. Run:

```powershell
.\update-vencord.ps1
```

The Vencord checkout lives in `Vencord/` (gitignored). Plugins hook in via `hooks/`, see [hooks/README.md](hooks/README.md). `orionQuests` ships built in.

## Linux

Requires `git`, `pnpm`, `node`. Run:

```bash
./update-vencord.sh
```

After the build it deploys to Vesktop (`~/.config/vesktop`) and to `~/.config/Vencord/dist` for Discord (native or Flatpak), then tells you whether Discord still needs `pnpm inject` (with `sudo` for a system Flatpak). `VENCORD_SKIP_DEPLOY=1 ./update-vencord.sh` stops right after the build.
