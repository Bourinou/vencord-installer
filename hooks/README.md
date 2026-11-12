# Hooks

`update-vencord.ps1` (Windows) and `update-vencord.sh` (Linux) run every file in this folder, in alphabetical order, after `pnpm install` and before `pnpm build`.

- `*.mjs` - run with `node <hook> <vencordDir>` (cross-platform, preferred)
- `*.ps1` - run with pwsh/powershell by the Windows installer, skipped on Linux
- `*.sh` - run with bash by the Linux installer, skipped on Windows

## Contract

- First argument: absolute path of the Vencord checkout.
- Idempotent: running it twice gives the same result.
- Exit code != 0 stops the installer before the build.
- Prefix file names with a number to control the order (`10-...`, `50-...`).

## Adding a plugin's hook

Plugin repos ship their own hook. Link it here (symlinks are resolved, so the hook can find its repo):

```powershell
New-Item -ItemType SymbolicLink -Path hooks\50-venchrome.mjs -Target C:\path\to\Venchrome\vencord-hook\50-venchrome.mjs
```
```bash
# Linux
ln -s /path/to/Venchrome/vencord-hook/50-venchrome.mjs hooks/50-venchrome.mjs
```

Symlinks on Windows need Developer Mode or an elevated shell. Alternative: copy the hook and set the env var it documents (e.g. `VENCHROME_DIR`).
