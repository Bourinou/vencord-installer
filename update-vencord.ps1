$ErrorActionPreference = "Stop"

# Evite que pnpm inject demande une confirmation :
$env:CI = "true"

function Fail($msg) {
    Write-Host ""
    Write-Host "ERREUR : $msg" -ForegroundColor Red
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

# Verifie que les dependances sont installees
foreach ($tool in "git", "pnpm", "node") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Fail "L'outil '$tool' est introuvable, installe-le puis relance le script."
    }
}

$root = $PSScriptRoot
$vencordDir = Join-Path $root "Vencord"

# Pour clone ou pull vencord
if (-not (Test-Path (Join-Path $vencordDir ".git"))) {
    Write-Host ">> Dossier Vencord absent, clonage..." -ForegroundColor Cyan
    git clone https://github.com/Vendicated/Vencord.git $vencordDir
    if ($LASTEXITCODE -ne 0) { Fail "git clone a echoue." }
} else {
    Write-Host ">> Mise a jour de Vencord (git pull)..." -ForegroundColor Cyan
    Set-Location $vencordDir
    git pull
    if ($LASTEXITCODE -ne 0) { Fail "git pull a echoue." }
}

Set-Location $vencordDir

# pnpm install
Write-Host ">> pnpm install..." -ForegroundColor Cyan
pnpm install --frozen-lockfile
if ($LASTEXITCODE -ne 0) { Fail "pnpm install a echoue." }

# hooks : chaque plugin ajoute son etape dans hooks/ (ordre alphabetique)
Write-Host ">> Execution des hooks..." -ForegroundColor Cyan
$hooksDir = Join-Path $root "hooks"
if (Test-Path $hooksDir) {
    $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    foreach ($hook in (Get-ChildItem $hooksDir -File | Sort-Object Name)) {
        $ext = $hook.Extension.ToLower()
        if ($ext -eq ".mjs") { Write-Host "   $($hook.Name)"; node $hook.FullName $vencordDir }
        elseif ($ext -eq ".ps1") { Write-Host "   $($hook.Name)"; & $psExe -NoProfile -File $hook.FullName $vencordDir }
        else { continue }
        if ($LASTEXITCODE -ne 0) { Fail "le hook $($hook.Name) a echoue." }
    }
}

# pnpm build
Write-Host ">> pnpm build..." -ForegroundColor Cyan
pnpm build
if ($LASTEXITCODE -ne 0) { Fail "pnpm build a echoue." }

# pnpm inject qui evite de saisir le chemin a la main
$discordPath = $null
foreach ($candidate in "Discord", "DiscordPTB", "DiscordCanary") {
    $p = Join-Path $env:LOCALAPPDATA $candidate
    if (Test-Path $p) { $discordPath = $p; break }
}

if ($discordPath) {
    Write-Host ">> pnpm inject (installation detectee : $discordPath)..." -ForegroundColor Cyan
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    pnpm inject --location $discordPath 2>&1 | Tee-Object -Variable injectOutput
    $ErrorActionPreference = $oldErrorAction
    if (($LASTEXITCODE -ne 0) -or ($injectOutput -match "Something went wrong")) {
        Fail "pnpm inject a echoue."
    }
} else {
    Write-Host ">> pnpm inject (installation de Discord introuvable, inject manuel)..." -ForegroundColor Yellow
    pnpm inject
    if ($LASTEXITCODE -ne 0) { Fail "pnpm inject a echoue." }
}

Write-Host ""
Write-Host "C'est tout bon." -ForegroundColor Green
Read-Host "Appuie sur Entree pour fermer"
