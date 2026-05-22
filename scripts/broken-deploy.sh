#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Démo rollback automatique
# Simule un déploiement cassé (image inexistante) → rollback Helm
# Usage : ./broken-deploy.sh [staging|production]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENV=${1:-staging}
NAMESPACE="kubequest-${ENV}"
RELEASE="kubequest-app"

log()     { echo -e "\033[0;34m[$(date '+%H:%M:%S')] $*\033[0m"; }
success() { echo -e "\033[0;32m[✓] $*\033[0m"; }
warn()    { echo -e "\033[0;33m[!] $*\033[0m"; }
error()   { echo -e "\033[0;31m[✗] $*\033[0m"; }

log "=== KubeQuest — Démo Rollback ==="
echo ""

# ─── État actuel ──────────────────────────────────────────────────────────────
log "1. État AVANT le déploiement cassé :"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app"
CURRENT_REVISION=$(helm history "$RELEASE" -n "$NAMESPACE" --max 1 -o json | jq -r '.[0].revision')
log "   Revision Helm actuelle : $CURRENT_REVISION"
echo ""

# ─── Déploiement cassé ────────────────────────────────────────────────────────
warn "2. Déploiement d'une image INEXISTANTE (image:this-tag-does-not-exist)..."
helm upgrade "$RELEASE" ./app/helm-chart \
  --namespace "$NAMESPACE" \
  --values ./app/helm-chart/values.yaml \
  --values ./app/helm-chart/values/${ENV}.yaml \
  --set app.image.tag="this-tag-does-not-exist" \
  --timeout 60s \
  --wait || {
    warn "Déploiement en échec comme prévu (ErrImagePull)"
    echo ""

    # ─── Observer l'erreur ────────────────────────────────────────────────────
    log "3. Observation de l'erreur K8s :"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app"
    echo ""
    FAILED_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app" \
      --field-selector=status.phase!=Running --no-headers -o name 2>/dev/null | head -1)
    if [[ -n "$FAILED_POD" ]]; then
      kubectl describe "$FAILED_POD" -n "$NAMESPACE" | grep -A 5 "Events:"
    fi
    echo ""

    # ─── Rollback ─────────────────────────────────────────────────────────────
    log "4. Rollback vers la revision $CURRENT_REVISION..."
    helm rollback "$RELEASE" "$CURRENT_REVISION" -n "$NAMESPACE" --wait

    success "Rollback effectué avec succès !"
    echo ""
    log "5. État APRÈS rollback :"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=kubequest-app"
    echo ""
    helm history "$RELEASE" -n "$NAMESPACE" --max 5
    exit 0
  }

warn "Le déploiement cassé n'a pas échoué comme attendu. Vérifier la config."
