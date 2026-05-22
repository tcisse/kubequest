#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# KubeQuest — Installation K3s (Amazon Linux 2023)
#
# Architecture :
#   kube-1     : control plane + worker  → ./k3s-install.sh master
#   kube-2     : worker                  → ./k3s-install.sh worker <MASTER_IP> <TOKEN>
#   ingress    : worker dédié ingress    → ./k3s-install.sh ingress <MASTER_IP> <TOKEN>
#   monitoring : worker dédié monitoring → ./k3s-install.sh monitoring <MASTER_IP> <TOKEN>
#
# Pré-requis : connecté en SSH avec le fichier kubequest.pem
#   ssh -i ~/.ssh/kubequest.pem ec2-user@<IP>
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ROLE=${1:-}
K3S_VERSION="v1.29.3+k3s1"

log()     { echo -e "\033[0;34m[$(date '+%H:%M:%S')] $*\033[0m"; }
success() { echo -e "\033[0;32m[✓] $*\033[0m"; }
error()   { echo -e "\033[0;31m[✗] $*\033[0m" >&2; exit 1; }

[[ -z "$ROLE" ]] && error "Usage: $0 master | worker | ingress | monitoring  [MASTER_IP] [TOKEN]"

# ─── Prérequis (Amazon Linux 2023 → dnf) ─────────────────────────────────────
install_prerequisites() {
  log "Installation des prérequis (Amazon Linux 2023)..."
  # On évite dnf update car curl-minimal entre en conflit avec curl dans les repos
  # curl-minimal est déjà présent et suffisant pour K3s
  sudo dnf install -y wget git jq nc --skip-broken 2>/dev/null || true

  # Désactiver le swap (Amazon Linux 2023 n'en a généralement pas, mais par sécurité)
  sudo swapoff -a 2>/dev/null || true
  sudo sed -i '/swap/d' /etc/fstab 2>/dev/null || true

  # Modules kernel requis par K8s
  sudo modprobe br_netfilter overlay 2>/dev/null || true
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF

  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
  sudo sysctl --system -q
  success "Prérequis installés"
}

# ─── Master (kube-1) ──────────────────────────────────────────────────────────
install_master() {
  log "Installation K3s MASTER sur kube-1..."

  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - \
    --disable traefik \
    --node-name kube-1 \
    --node-label "node-role=worker" \
    --write-kubeconfig-mode 644

  log "Attente que le cluster soit prêt..."
  until sudo kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    echo -n "."; sleep 3
  done
  echo ""

  # Configurer kubectl pour ec2-user
  mkdir -p "$HOME/.kube"
  sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
  export KUBECONFIG="$HOME/.kube/config"

  # Ajouter KUBECONFIG au profil shell
  echo 'export KUBECONFIG=$HOME/.kube/config' >> "$HOME/.bashrc"

  install_tools

  success "Master K3s prêt !"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  NODE TOKEN (à copier pour joindre les workers) :"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  sudo cat /var/lib/rancher/k3s/server/node-token
  echo ""
  PRIVATE_IP=$(hostname -I | awk '{print $1}')
  echo "  Commandes pour les autres nœuds (IP privée master = $PRIVATE_IP) :"
  echo "  kube-2     : ./k3s-install.sh worker     $PRIVATE_IP <TOKEN>"
  echo "  ingress    : ./k3s-install.sh ingress    $PRIVATE_IP <TOKEN>"
  echo "  monitoring : ./k3s-install.sh monitoring $PRIVATE_IP <TOKEN>"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  kubectl get nodes -o wide
}

# ─── Worker (kube-2) ──────────────────────────────────────────────────────────
install_worker() {
  MASTER_IP=${2:-}; TOKEN=${3:-}
  [[ -z "$MASTER_IP" || -z "$TOKEN" ]] && error "Usage: $0 worker <MASTER_IP> <TOKEN>"

  log "Installation K3s WORKER (kube-2) → master $MASTER_IP..."

  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
    K3S_URL="https://${MASTER_IP}:6443" \
    K3S_TOKEN="$TOKEN" \
    sh -s - \
    --node-name kube-2 \
    --node-label "node-role=worker"

  success "Worker kube-2 joint au cluster !"
}

# ─── Nœud ingress dédié ───────────────────────────────────────────────────────
install_ingress_node() {
  MASTER_IP=${2:-}; TOKEN=${3:-}
  [[ -z "$MASTER_IP" || -z "$TOKEN" ]] && error "Usage: $0 ingress <MASTER_IP> <TOKEN>"

  log "Installation K3s nœud INGRESS → master $MASTER_IP..."

  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
    K3S_URL="https://${MASTER_IP}:6443" \
    K3S_TOKEN="$TOKEN" \
    sh -s - \
    --node-name ingress \
    --node-label "node-role=ingress" \
    --node-taint "dedicated=ingress:NoSchedule"

  success "Nœud ingress joint au cluster !"
  echo "  Depuis kube-1, vérifier : kubectl get nodes -o wide"
}

# ─── Nœud monitoring dédié ────────────────────────────────────────────────────
install_monitoring_node() {
  MASTER_IP=${2:-}; TOKEN=${3:-}
  [[ -z "$MASTER_IP" || -z "$TOKEN" ]] && error "Usage: $0 monitoring <MASTER_IP> <TOKEN>"

  log "Installation K3s nœud MONITORING → master $MASTER_IP..."

  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
    K3S_URL="https://${MASTER_IP}:6443" \
    K3S_TOKEN="$TOKEN" \
    sh -s - \
    --node-name monitoring \
    --node-label "node-role=monitoring" \
    --node-taint "dedicated=monitoring:NoSchedule"

  success "Nœud monitoring joint au cluster !"
}

# ─── Outils complémentaires (master uniquement) ───────────────────────────────
install_tools() {
  log "Installation des outils : helm, kubectx, kubens, kustomize..."

  # Helm
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  # kubectx + kubens — détection automatique de l'architecture (x86_64 ou aarch64)
  local KUBECTX_VERSION="0.9.5"
  local ARCH
  ARCH=$(uname -m)
  [[ "$ARCH" == "aarch64" ]] && ARCH="arm64" || ARCH="x86_64"
  for tool in kubectx kubens; do
    curl -sLo "/tmp/${tool}.tar.gz" \
      "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/${tool}_v${KUBECTX_VERSION}_linux_${ARCH}.tar.gz"
    sudo tar -xf "/tmp/${tool}.tar.gz" -C /usr/local/bin "$tool"
    rm "/tmp/${tool}.tar.gz"
  done

  # kustomize
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/

  success "Outils installés : helm, kubectx, kubens, kustomize"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
install_prerequisites

case "$ROLE" in
  master)     install_master ;;
  worker)     install_worker "$@" ;;
  ingress)    install_ingress_node "$@" ;;
  monitoring) install_monitoring_node "$@" ;;
  *)          error "Rôle inconnu : '$ROLE'. Utiliser master | worker | ingress | monitoring" ;;
esac
