#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Demo: récupère le token admin du Kubernetes Dashboard
#
# Usage depuis le Mac :
#   ./scripts/demo-token.sh
#
# Le token est imprimé sur stdout ET copié dans le presse-papier (pbcopy).
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

KUBE1_HOST="${KUBE1_HOST:-ec2-user@52.211.176.178}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/kubequest.pem}"

TOKEN=$(ssh -i "$SSH_KEY" "$KUBE1_HOST" \
  'kubectl -n kubernetes-dashboard create token admin-user --duration=1h')

echo "$TOKEN"

if command -v pbcopy >/dev/null; then
  echo -n "$TOKEN" | pbcopy
  echo
  echo "✓ Token copié dans le presse-papier — colle-le dans le Dashboard."
fi
