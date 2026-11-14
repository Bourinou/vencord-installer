// Windows updater: run with `node update-vencord.mjs` (no PowerShell execution policy, no SmartScreen).
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline/promises";

// Evite que pnpm inject demande une confirmation :
process.env.CI = "true";

const color = { red: 31, green: 32, yellow: 33, cyan: 36 };
const say = (msg, c) => console.log(c ? `\x1b[${color[c]}m${msg}\x1b[0m` : msg);

async function pause() {
    if (!process.stdin.isTTY) return;
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    await rl.question("Appuie sur Entree pour fermer");
    rl.close();
}

async function fail(msg) {
    say("");
    say(`ERREUR : ${msg}`, "red");
    await pause();
    process.exit(1);
}

// shell: true pour trouver pnpm.cmd sous Windows
function run(cmd, args, opts = {}) {
    const quoted = args.map(a => (/[\s"]/.test(a) ? `"${a}"` : a));
    return spawnSync(cmd, quoted, { stdio: "inherit", shell: true, ...opts });
}

// Verifie que les dependances sont installees
for (const tool of ["git", "pnpm", "node"]) {
    const probe = spawnSync(process.platform === "win32" ? "where" : "which", [tool], { stdio: "ignore" });
    if (probe.status !== 0) await fail(`L'outil '${tool}' est introuvable, installe-le puis relance le script.`);
}

const root = dirname(fileURLToPath(import.meta.url));
const vencordDir = join(root, "Vencord");

// Pour clone ou pull vencord
if (!existsSync(join(vencordDir, ".git"))) {
    say(">> Dossier Vencord absent, clonage...", "cyan");
    if (run("git", ["clone", "https://github.com/Vendicated/Vencord.git", vencordDir]).status !== 0) await fail("git clone a echoue.");
} else {
    say(">> Mise a jour de Vencord (git pull)...", "cyan");
    if (run("git", ["pull"], { cwd: vencordDir }).status !== 0) await fail("git pull a echoue.");
}

const inVencord = { cwd: vencordDir };

// pnpm install
say(">> pnpm install...", "cyan");
if (run("pnpm", ["install", "--frozen-lockfile"], inVencord).status !== 0) await fail("pnpm install a echoue.");

// hooks : chaque plugin ajoute son etape dans hooks/ (ordre alphabetique)
say(">> Execution des hooks...", "cyan");
const hooksDir = join(root, "hooks");
if (existsSync(hooksDir)) {
    const psExe = spawnSync("where", ["pwsh"], { stdio: "ignore" }).status === 0 ? "pwsh" : "powershell";
    for (const name of readdirSync(hooksDir).sort()) {
        const full = join(hooksDir, name);
        if (!statSync(full).isFile()) continue;
        const ext = extname(name).toLowerCase();
        let res;
        if (ext === ".mjs") { say(`   ${name}`); res = run("node", [full, vencordDir], inVencord); }
        else if (ext === ".ps1") { say(`   ${name}`); res = run(psExe, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", full, vencordDir], inVencord); }
        else continue;
        if (res.status !== 0) await fail(`le hook ${name} a echoue.`);
    }
}

// pnpm build
say(">> pnpm build...", "cyan");
if (run("pnpm", ["build"], inVencord).status !== 0) await fail("pnpm build a echoue.");

// pnpm inject qui evite de saisir le chemin a la main
const discordPath = ["Discord", "DiscordPTB", "DiscordCanary"]
    .map(c => join(process.env.LOCALAPPDATA ?? "", c))
    .find(p => existsSync(p));

if (discordPath) {
    say(`>> pnpm inject (installation detectee : ${discordPath})...`, "cyan");
    const res = run("pnpm", ["inject", "--location", discordPath], { ...inVencord, stdio: ["inherit", "pipe", "pipe"], encoding: "utf8" });
    const out = `${res.stdout ?? ""}${res.stderr ?? ""}`;
    process.stdout.write(out);
    if (res.status !== 0 || out.includes("Something went wrong")) await fail("pnpm inject a echoue.");
} else {
    say(">> pnpm inject (installation de Discord introuvable, inject manuel)...", "yellow");
    if (run("pnpm", ["inject"], inVencord).status !== 0) await fail("pnpm inject a echoue.");
}

say("");
say("C'est tout bon.", "green");
await pause();
