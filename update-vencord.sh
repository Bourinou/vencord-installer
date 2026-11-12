#!/usr/bin/env bash
set -e

# ==============================================================================
# Script de mise à jour / installation de Vencord + plugins (hooks/)
# Adapté pour Arch Linux (Vesktop & Discord Flatpak / Natif)
# VENCORD_SKIP_DEPLOY=1 : s'arrête après le build (pas de déploiement/inject).
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

fail() {
    echo -e "\n${RED}ERREUR : $1${NC}"
    exit 1
}

# 1. Vérification des dépendances
for tool in git pnpm node; do
    if ! command -v "$tool" &>/dev/null; then
        fail "L'outil '$tool' n'est pas installé sur votre système."
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENCORD_DIR="$SCRIPT_DIR/Vencord"
HOOKS_DIR="$SCRIPT_DIR/hooks"

# 2. Cloner ou mettre à jour Vencord
if [ ! -d "$VENCORD_DIR/.git" ]; then
    echo -e "${CYAN}>> Dossier Vencord absent, clonage...${NC}"
    git clone https://github.com/Vendicated/Vencord.git "$VENCORD_DIR" || fail "git clone a échoué."
else
    echo -e "${CYAN}>> Mise à jour de Vencord (git pull)...${NC}"
    git -C "$VENCORD_DIR" pull || fail "git pull a échoué."
fi

cd "$VENCORD_DIR"

# 3. Installation des dépendances Vencord
echo -e "${CYAN}>> pnpm install...${NC}"
pnpm install --frozen-lockfile || fail "pnpm install a échoué."

# 4. Hooks : chaque plugin ajoute son étape dans hooks/ (ordre alphabétique)
echo -e "${CYAN}>> Exécution des hooks...${NC}"
if [ -d "$HOOKS_DIR" ]; then
    for hook in "$HOOKS_DIR"/*; do
        [ -f "$hook" ] || continue
        name="$(basename "$hook")"
        case "$name" in
            *.mjs) echo "   $name"; node "$hook" "$VENCORD_DIR" || fail "le hook $name a échoué." ;;
            *.sh)  echo "   $name"; bash "$hook" "$VENCORD_DIR" || fail "le hook $name a échoué." ;;
            *) ;; # .ps1 (Windows) et autres : ignorés
        esac
    done
fi

# 5. Build de Vencord (génère à la fois les bundles Discord et Vesktop)
echo -e "${CYAN}>> pnpm build...${NC}"
pnpm build || fail "pnpm build a échoué."

if [ "${VENCORD_SKIP_DEPLOY:-}" = "1" ]; then
    echo -e "\n${YELLOW}>> VENCORD_SKIP_DEPLOY=1 : build terminé, déploiement ignoré.${NC}"
    exit 0
fi

# S'assurer que package.json existe dans dist pour la validation Vesktop
if [ ! -f "$VENCORD_DIR/dist/package.json" ]; then
    echo "{}" > "$VENCORD_DIR/dist/package.json"
fi

# 6. Déploiement pour Vesktop
echo -e "\n${CYAN}>> Déploiement pour Vesktop...${NC}"
VESKTOP_CONFIG_DIR="$HOME/.config/vesktop"
VESKTOP_SESSION_FILES="$VESKTOP_CONFIG_DIR/sessionData/vencordFiles"

if [ -d "$VESKTOP_CONFIG_DIR" ]; then
    mkdir -p "$VESKTOP_SESSION_FILES"
    cp -f "$VENCORD_DIR"/dist/vencordDesktopMain.js* "$VESKTOP_SESSION_FILES/" 2>/dev/null || true
    cp -f "$VENCORD_DIR"/dist/vencordDesktopPreload.js* "$VESKTOP_SESSION_FILES/" 2>/dev/null || true
    cp -f "$VENCORD_DIR"/dist/vencordDesktopRenderer.js* "$VESKTOP_SESSION_FILES/" 2>/dev/null || true
    cp -f "$VENCORD_DIR"/dist/vencordDesktopRenderer.css* "$VESKTOP_SESSION_FILES/" 2>/dev/null || true
    cp -f "$VENCORD_DIR"/dist/package.json "$VESKTOP_SESSION_FILES/" 2>/dev/null || true

    # Mettre à jour state.json pour pointer également vencordDir vers dist
    STATE_FILE="$VESKTOP_CONFIG_DIR/state.json"
    if [ -f "$STATE_FILE" ]; then
        node -e "
            const fs = require('fs');
            const [file, dist] = process.argv.slice(1);
            try {
                const state = JSON.parse(fs.readFileSync(file, 'utf8'));
                state.vencordDir = dist;
                fs.writeFileSync(file, JSON.stringify(state, null, 4));
            } catch(e) {}
        " "$STATE_FILE" "$VENCORD_DIR/dist"
    fi
    echo -e "${GREEN}✔ Vesktop configuré avec succès avec le Vencord personnalisé (plugins inclus).${NC}"
else
    echo -e "${YELLOW}>> Vesktop non configuré (~/.config/vesktop introuvable).${NC}"
fi

# 7. Déploiement pour Discord (Global ~/.config/Vencord/dist)
echo -e "\n${CYAN}>> Déploiement pour Discord standard...${NC}"
GLOBAL_VENCORD_DIST="$HOME/.config/Vencord/dist"
mkdir -p "$GLOBAL_VENCORD_DIST"
cp -rf "$VENCORD_DIR"/dist/* "$GLOBAL_VENCORD_DIST/"
echo -e "${GREEN}✔ Fichiers Discord copiés dans $GLOBAL_VENCORD_DIST.${NC}"

# S'assurer que le Flatpak Discord a accès au dossier
if command -v flatpak &>/dev/null && flatpak list | grep -q "com.discordapp.Discord"; then
    flatpak override --user com.discordapp.Discord --filesystem="$GLOBAL_VENCORD_DIST" 2>/dev/null || true
fi

# 8. Vérification de l'injection Discord
FLATPAK_DISCORD_RESOURCES="/var/lib/flatpak/app/com.discordapp.Discord/current/active/files/discord/resources"
USER_FLATPAK_DISCORD_RESOURCES="$HOME/.local/share/flatpak/app/com.discordapp.Discord/current/active/files/discord/resources"
OPT_DISCORD_RESOURCES="/opt/discord/resources"
USR_DISCORD_RESOURCES="/usr/share/discord/resources"

DISCORD_PATCHED=false

for res in "$FLATPAK_DISCORD_RESOURCES" "$USER_FLATPAK_DISCORD_RESOURCES" "$OPT_DISCORD_RESOURCES" "$USR_DISCORD_RESOURCES"; do
    if [ -f "$res/_app.asar" ]; then
        DISCORD_PATCHED=true
        break
    fi
done

if [ "$DISCORD_PATCHED" = true ]; then
    echo -e "${GREEN}✔ Discord est déjà patché/injecté (les mises à jour sont automatiquement prises en compte).${NC}"
else
    echo -e "\n${YELLOW}>> Discord ne semble pas encore injecté ou a été réinitialisé par une mise à jour.${NC}"
    echo -e "${CYAN}>> Pour injecter Vencord dans Discord :${NC}"
    if [ -d "$FLATPAK_DISCORD_RESOURCES" ]; then
        echo -e "${YELLOW}   Votre Discord Flatpak étant installé au niveau système, l'injection initiale requiert sudo :${NC}"
        echo -e "   cd \"$VENCORD_DIR\" && sudo pnpm inject"
    else
        echo -e "   cd \"$VENCORD_DIR\" && pnpm inject"
    fi
fi

echo -e "\n${GREEN}Tout est prêt ! Pensez à redémarrer Vesktop / Discord pour charger les nouveautés.${NC}"
