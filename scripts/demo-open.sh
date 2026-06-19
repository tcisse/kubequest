#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Demo: ouvre les port-forwards vers toutes les UIs
#
# À EXÉCUTER SUR kube-1 (ou n'importe quelle machine avec kubectl + kubeconfig)
#
# Usage local :
#   ./scripts/demo-open.sh
#
# Usage via SSH depuis le Mac (cf. demo-tunnel.sh) :
#   ssh ... -L ... user@kube-1 "bash -lc './scripts/demo-open.sh'"
#
# Ctrl+C pour tout arrêter (les port-forwards sont nettoyés via trap).
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

NS_APP="${NS_APP:-kubequest-staging}"
BIND_ADDR="${BIND_ADDR:-127.0.0.1}"

c_blue='\033[0;34m'; c_green='\033[0;32m'; c_yellow='\033[0;33m'
c_red='\033[0;31m'; c_dim='\033[0;90m'; c_off='\033[0m'

log()     { echo -e "${c_blue}[$(date '+%H:%M:%S')] $*${c_off}"; }
success() { echo -e "${c_green}[✓] $*${c_off}"; }
warn()    { echo -e "${c_yellow}[!] $*${c_off}"; }
fail()    { echo -e "${c_red}[✗] $*${c_off}"; }

PIDS=()
cleanup() {
  echo
  log "Arrêt des port-forwards..."
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  success "Tout est arrêté."
}
trap cleanup EXIT INT TERM

# ─── Vérifs ──────────────────────────────────────────────────────────────────
command -v kubectl >/dev/null || { fail "kubectl introuvable"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { fail "Cluster K8s non joignable"; exit 1; }

# ─── Détection des services ──────────────────────────────────────────────────
log "Détection des services..."

GRAFANA_SVC=$(kubectl -n monitoring get svc -l app.kubernetes.io/name=grafana \
              -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[[ -z "$GRAFANA_SVC" ]] && warn "Grafana introuvable dans namespace 'monitoring'"

PROM_SVC="prometheus-operated"
kubectl -n monitoring get svc "$PROM_SVC" >/dev/null 2>&1 || {
  PROM_SVC=$(kubectl -n monitoring get svc -l app.kubernetes.io/name=prometheus \
             -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
}
[[ -z "$PROM_SVC" ]] && warn "Prometheus introuvable"

ARGOCD_SVC="argocd-server"
kubectl -n argocd get svc "$ARGOCD_SVC" >/dev/null 2>&1 || ARGOCD_SVC=""
[[ -z "$ARGOCD_SVC" ]] && warn "ArgoCD introuvable dans namespace 'argocd'"

DASH_SVC=$(kubectl -n kubernetes-dashboard get svc -o name 2>/dev/null \
           | grep -E "kong-proxy|dashboard-web" | head -1 | sed 's|service/||')
[[ -z "$DASH_SVC" ]] && warn "Dashboard introuvable dans namespace 'kubernetes-dashboard'"

APP_SVC=$(kubectl -n "$NS_APP" get svc -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[[ -z "$APP_SVC" ]] && warn "App introuvable dans namespace '$NS_APP'"

# ─── Lance un port-forward ───────────────────────────────────────────────────
start_pf() {
  local ns=$1 svc=$2 local_port=$3 svc_port=$4 label=$5 url_proto=$6
  [[ -z "$svc" ]] && return
  kubectl -n "$ns" port-forward --address "$BIND_ADDR" "svc/$svc" \
    "$local_port:$svc_port" >/tmp/pf-"$label".log 2>&1 &
  PIDS+=($!)
  printf "  ${c_green}%-18s${c_off} → ${url_proto}://%s:%s   ${c_dim}(svc/%s:%s)${c_off}\n" \
    "$label" "$BIND_ADDR" "$local_port" "$svc" "$svc_port"
}

echo
log "=== KubeQuest demo — port-forwards actifs ==="
echo

start_pf monitoring             "$GRAFANA_SVC" 3000 80   "Grafana"       http
start_pf monitoring             "$PROM_SVC"    9090 9090 "Prometheus"    http
start_pf argocd                 "$ARGOCD_SVC"  8080 80   "ArgoCD"        http
start_pf kubernetes-dashboard   "$DASH_SVC"    8443 443  "K8s-Dashboard" https
start_pf "$NS_APP"              "$APP_SVC"     8000 80   "Laravel-App"   http

cat <<EOF

${c_yellow}━━━ Identifiants ━━━${c_off}
  Grafana          admin / changeme-in-secret
  ArgoCD           admin / kubequest-admin
  K8s Dashboard    token via :
                   kubectl -n kubernetes-dashboard create token admin-user

${c_dim}Logs des port-forwards : /tmp/pf-*.log
Ctrl+C pour tout arrêter.${c_off}

EOF

# Bloque jusqu'au signal (les PF tournent en background)
wait
