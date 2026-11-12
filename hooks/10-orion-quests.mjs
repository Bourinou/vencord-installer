// Installs the orionQuests plugin into <vencord>/src/plugins/orionQuests.
// Usage: node 10-orion-quests.mjs <vencordDir>. Idempotent.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const vencordDir = process.argv[2];
if (!vencordDir) { console.error("usage: node 10-orion-quests.mjs <vencordDir>"); process.exit(1); }

const pluginsDir = path.join(vencordDir, "src", "plugins");
const orionDir = path.join(pluginsDir, "orionQuests");
const tempDir = path.join(pluginsDir, "_orion-temp");

const hasFiles = dir => fs.readdirSync(dir, { withFileTypes: true, recursive: true }).some(e => !e.isDirectory());

console.log("[orionQuests] installing plugin...");
for (const e of fs.readdirSync(pluginsDir, { withFileTypes: true })) {
    const p = path.join(pluginsDir, e.name);
    if (e.isDirectory() && !hasFiles(p)) fs.rmSync(p, { recursive: true, force: true });
}
fs.rmSync(tempDir, { recursive: true, force: true });
fs.rmSync(orionDir, { recursive: true, force: true });

const r = spawnSync("git", ["clone", "--depth", "1", "https://github.com/nyxxbit/discord-quest-completer.git", tempDir], { stdio: "inherit" });
if (r.status !== 0) { console.error("[orionQuests] git clone failed"); process.exit(1); }
fs.renameSync(tempDir, orionDir);
console.log("[orionQuests] done");
