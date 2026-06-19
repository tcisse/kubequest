#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Demo: tunnel SSH Mac → kube-1 + ouverture des UIs
#
# À EXÉCUTER SUR LE MAC.
#
# Prérequis :
#   - clé SSH : ~/.ssh/kubequest.pem
#   - le projet kubequest cloné dans le home de kube-1 (~/kubequest)
#
# Usage :
#   ./scripts/demo-tunnel.sh
#
# Variables d'environnement :
#   KUBE1_HOST   user@host (par défaut: ec2-user@52.211.176.178)
#   SSH_KEY      chemin de la clé SSH (par défaut: ~/.ssh/kubequest.pem)
#   NS_APP       namespace de l'app (par défaut: kubequest-staging)
#   REMOTE_DIR   dossier du projet sur kube-1 (par défaut: ~/kubequest)
#   NO_BROWSER   si défini, n'ouvre pas le navigateur
#
# Ctrl+C pour tout fermer (tunnel + port-forwards remote).
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

KUBE1_HOST="${KUBE1_HOST:-ec2-user@52.211.176.178}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/kubequest.pem}"
NS_APP="${NS_APP:-kubequest-staging}"
REMOTE_DIR="${REMOTE_DIR:-~/kubequest}"

c_blue='\033[0;34m'; c_green='\033[0;32m'; c_yellow='\033[0;33m'
c_dim='\033[0;90m'; c_off='\033[0m'

cat <<EOF
${c_blue}═══════════════════════════════════════════════════${c_off}
${c_blue}     KubeQuest — Démo : accès aux UIs              ${c_off}
${c_blue}═══════════════════════════════════════════════════${c_off}

  Cible       : ${c_green}$KUBE1_HOST${c_off}
  Clé SSH     : $SSH_KEY
  Namespace   : $NS_APP

EOF

[[ -f "$SSH_KEY" ]] || { echo "Clé SSH introuvable: $SSH_KEY"; exit 1; }

# Ouverture du navigateur en arrière-plan (après que les tunnels soient prêts)
open_browser() {
  [[ -n "${NO_BROWSER:-}" ]] && return
  sleep 6
  echo -e "${c_blue}[*] Ouverture des onglets dans le navigateur...${c_off}"
  open "http://localhost:3000"   # Grafana
  open "http://localhost:9090"   # Prometheus
  open "http://localhost:8080"   # ArgoCD
  open "https://localhost:8443"  # K8s Dashboard
  open "http://localhost:8000"   # Laravel App
}
open_browser &
BROWSER_PID=$!
trap "kill $BROWSER_PID 2>/dev/null || true" EXIT

cat <<EOF
${c_yellow}━━━ URLs locales (une fois le tunnel établi) ━━━${c_off}
  Grafana          http://localhost:3000       admin / changeme-in-secret
  Prometheus       http://localhost:9090
  ArgoCD           http://localhost:8080       admin / kubequest-admin
  K8s Dashboard    https://localhost:8443      (token requis)
  Laravel App      http://localhost:8000

${c_dim}Pour le token Dashboard, dans un autre terminal :
  ssh -i $SSH_KEY $KUBE1_HOST 'kubectl -n kubernetes-dashboard create token admin-user'${c_off}

${c_blue}[*] Ouverture du tunnel SSH + lancement des port-forwards remote...${c_off}
${c_dim}    (Ctrl+C pour tout fermer)${c_off}

EOF

exec ssh -i "$SSH_KEY" -t \
  -L 3000:localhost:3000 \
  -L 9090:localhost:9090 \
  -L 8080:localhost:8080 \
  -L 8443:localhost:8443 \
  -L 8000:localhost:8000 \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  "$KUBE1_HOST" \
  "cd $REMOTE_DIR && NS_APP=$NS_APP BIND_ADDR=127.0.0.1 bash ./scripts/demo-open.sh"
