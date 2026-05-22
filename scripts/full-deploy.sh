#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Déploiement complet from scratch
# Usage : ./full-deploy.sh [staging|production]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENV=${1:-staging}
NAMESPACE="kubequest-${ENV}"

log()     { echo -e "\033[0;34m[$(date '+%H:%M:%S')] $*\033[0m"; }
success() { echo -e "\033[0;32m[✓] $*\033[0m"; }
warn()    { echo -e "\033[0;33m[!] $*\033[0m"; }

log "=== KubeQuest — Déploiement $ENV ==="

# ─── 1. Vérifications ─────────────────────────────────────────────────────────
log "Vérification des prérequis..."
for tool in kubectl helm kustomize; do
  command -v "$tool" &>/dev/null || { echo "ERREUR: $tool non trouvé"; exit 1; }
done
kubectl cluster-info &>/dev/null || { echo "ERREUR: Cluster K8s non accessible"; exit 1; }
success "Prérequis OK"

# ─── 2. Namespace ─────────────────────────────────────────────────────────────
log "Création du namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
success "Namespace $NAMESPACE prêt"

# ─── 3. Repos Helm ────────────────────────────────────────────────────────────
log "Ajout des repos Helm..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add dex https://charts.dexidp.io
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
success "Repos Helm configurés"

# ─── 4. Infra (nginx, dashboard, monitoring) ──────────────────────────────────
log "Déploiement de l'infrastructure de base..."
kustomize build --enable-helm infra/overlays/${ENV} | kubectl apply -f -

log "Attente nginx-ingress..."
kubectl rollout status deployment -n ingress-nginx -l app.kubernetes.io/component=controller --timeout=120s

log "Attente OPA Gatekeeper..."
kubectl rollout status deployment -n gatekeeper-system gatekeeper-controller-manager --timeout=120s
kubectl rollout status deployment -n gatekeeper-system gatekeeper-audit --timeout=120s
log "Attente Dex + oauth2-proxy..."
kubectl rollout status deployment -n auth dex --timeout=120s
kubectl rollout status deployment -n auth oauth2-proxy --timeout=120s
success "Infrastructure déployée (nginx, monitoring, dashboard, OPA Gatekeeper, Dex + oauth2-proxy)"

# ─── 5. Application (via Kustomize + Helm) ───────────────────────────────────
log "Déploiement de l'application via Kustomize (env: $ENV)..."
kustomize build --enable-helm app/kustomize/overlays/${ENV} | kubectl apply -f -

log "Attente du rollout de l'application..."
kubectl rollout status deployment -n "$NAMESPACE" kubequest-app --timeout=300s

success "Application déployée !"

# ─── 6. Résumé ────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ KubeQuest déployé en $ENV !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n "$NAMESPACE"
echo ""
echo "  App       : http://app.kubequest.local"
echo "  Dashboard : http://dashboard.kubequest.local"
echo "  Grafana   : http://grafana.kubequest.local"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
