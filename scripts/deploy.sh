#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  scripts/deploy.sh — exécuté SUR LE VPS par `make deploy`
# ═══════════════════════════════════════════════════════════════════
#  Déclenché en arrière-plan (nohup) depuis le poste local. Log complet
#  dans logs/deploy-<timestamp>.log + symlink logs/deploy-latest.log.
#
#  Côté utilisateur (local) :
#      make deploy [FORCE=1]    → lance, rend la main tout de suite
#      make deploy-logs         → tail -f du log courant
#      make deploy-status       → état (en cours / terminé / pods up)
#
#  Variables :
#      FORCE=1    wipe les jars plugins pour forcer retéléchargement itzg
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
NAMESPACE="${NAMESPACE:-mineshark}"
FORCE="${FORCE:-0}"

mkdir -p logs
PIDFILE="$ROOT/logs/deploy.pid"

# Garde-fou : un seul déploiement à la fois.
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "❌ Un déploiement est déjà en cours (PID $(cat "$PIDFILE")). Voir deploy-logs."
    exit 1
fi
echo $$ > "$PIDFILE"
# Supprime le pidfile à la sortie (succès ou échec)
trap 'rm -f "$PIDFILE"' EXIT

log() { echo "[deploy $(date +%H:%M:%S)] $*"; }

log "start — FORCE=$FORCE — branch $(git rev-parse --abbrev-ref HEAD)"

log "git pull…"
git pull --ff-only

if [ "$FORCE" = "1" ]; then
    log "FORCE=1 → fclean + up + attente rollout + update-plugins"
    make re
    log "attente rollout deploy/mc-main (timeout 6 min)…"
    kubectl -n "$NAMESPACE" rollout status deploy/mc-main --timeout=360s
    make update-plugins
else
    log "soft deploy → make re (plugins cachés conservés)"
    make re
fi

log "✓ déploiement terminé avec succès"
