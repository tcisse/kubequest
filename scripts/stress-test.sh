#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Script de stress test (déclenche l'autoscaling HPA)
# Usage : ./stress-test.sh [URL] [CONCURRENCY] [REQUESTS]
# Exemple: ./stress-test.sh http://app.kubequest.local 50 10000
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

TARGET_URL=${1:-"http://app.kubequest.local"}
CONCURRENCY=${2:-50}
TOTAL_REQUESTS=${3:-5000}
NAMESPACE=${4:-"kubequest-staging"}

log()     { echo -e "\033[0;34m[$(date '+%H:%M:%S')] $*\033[0m"; }
success() { echo -e "\033[0;32m[✓] $*\033[0m"; }

# ─── Vérifications ────────────────────────────────────────────────────────────
for tool in ab watch kubectl; do
  command -v "$tool" &>/dev/null || {
    echo "Installation de $tool..."
    sudo apt-get install -y apache2-utils procps 2>/dev/null || true
  }
done

log "=== KubeQuest — Stress Test ==="
log "Target  : $TARGET_URL"
log "Workers : $CONCURRENCY workers simultanés"
log "Total   : $TOTAL_REQUESTS requêtes"
echo ""

# ─── Snapshot avant ───────────────────────────────────────────────────────────
log "État initial des pods :"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app"
echo ""
log "État HPA initial :"
kubectl get hpa -n "$NAMESPACE"
echo ""

# ─── Lancer le monitoring en arrière-plan ────────────────────────────────────
log "Lancement du monitoring HPA (Ctrl+C pour arrêter)..."
(
  while true; do
    echo -n "[$(date '+%H:%M:%S')] Pods: "
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app" \
      --no-headers 2>/dev/null | wc -l
    echo -n " | HPA: "
    kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null | \
      awk '{print $6"/"$5" replicas, CPU: "$3}' || echo "N/A"
    sleep 10
  done
) &
MONITOR_PID=$!
trap "kill $MONITOR_PID 2>/dev/null; exit" INT TERM

# ─── Stress test ──────────────────────────────────────────────────────────────
log "Démarrage du stress test..."
ab -n "$TOTAL_REQUESTS" -c "$CONCURRENCY" \
   -H "Accept-Encoding: gzip,deflate" \
   "${TARGET_URL}/"

# ─── Résultat ─────────────────────────────────────────────────────────────────
kill $MONITOR_PID 2>/dev/null || true

echo ""
log "=== Résultat après stress test ==="
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app"
echo ""
kubectl get hpa -n "$NAMESPACE"
success "Stress test terminé !"
