# KubeQuest — Epitech Project

> Déploiement d'un cluster Kubernetes production-grade sur AWS avec monitoring, GitOps, sécurité et une application Laravel.

---

## Architecture

### Infrastructure AWS — 4 VMs (Amazon Linux 2023, ARM64 / aarch64)

| Nœud | IP Privée | Rôle | Taint |
|------|-----------|------|-------|
| `kube-1` | `10.1.24.122` | Control Plane + Worker | — |
| `kube-2` | `10.1.24.126` | Worker | — |
| `ingress` | `10.1.24.74` | Ingress Controller | `dedicated=ingress:NoSchedule` |
| `monitoring` | `10.1.24.68` | Stack Observabilité | `dedicated=monitoring:NoSchedule` |

> **Note :** Les VMs s'éteignent automatiquement chaque soir. Les services systemd (k3s, k3s-agent) redémarrent automatiquement au démarrage. Les IPs privées sont stables ; les IPs publiques peuvent changer.

---

## Ce qui a été fait

### Phase 1 — Cluster Kubernetes (K3s) ✅

#### Installation de K3s sur kube-1 (Control Plane)

K3s v1.29.3+k3s1 installé manuellement (ARM64) en contournant le conflit `curl-minimal` d'Amazon Linux 2023 :

```bash
# Désactiver le swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Charger les modules kernel
sudo modprobe br_netfilter overlay

# Installer les dépendances sans curl (curl-minimal déjà présent)
sudo dnf install -y wget git jq --skip-broken

# Installer K3s master (sans traefik, avec node-label worker)
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="v1.29.3+k3s1" \
  sh -s - server \
  --disable traefik \
  --node-name kube-1 \
  --node-label "node-role=worker"
```

**Outils installés sur kube-1 :**
- Helm v3.20.1
- kubectx / kubens v0.9.5 (ARM64)
- kustomize v5.8.1

**Configuration kubectl :**
```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
```

#### Node Token K3s

```
K1089d51b538d20afe3ff27780da79d60ff153a1899005a054b87045981c431c70d::server:6262b97dea29d5fbd9af2decab5a1695
```

> ⚠️ Le token est **sensible à la casse** (K majuscule). À re-vérifier après redémarrage via :
> `sudo cat /var/lib/rancher/k3s/server/node-token`

#### Jonction des 3 workers

```bash
# kube-2
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.1.24.122:6443 \
  K3S_TOKEN=K1089d51b538d20afe3ff27780da79d60ff153a1899005a054b87045981c431c70d::server:6262b97dea29d5fbd9af2decab5a1695 \
  INSTALL_K3S_VERSION="v1.29.3+k3s1" \
  sh -s - --node-name kube-2 --node-label "node-role=worker"

# ingress
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.1.24.122:6443 \
  K3S_TOKEN=K1089d51b538d20afe3ff27780da79d60ff153a1899005a054b87045981c431c70d::server:6262b97dea29d5fbd9af2decab5a1695 \
  INSTALL_K3S_VERSION="v1.29.3+k3s1" \
  sh -s - --node-name ingress \
  --node-label "node-role=ingress" \
  --node-taint "dedicated=ingress:NoSchedule"

# monitoring
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.1.24.122:6443 \
  K3S_TOKEN=K1089d51b538d20afe3ff27780da79d60ff153a1899005a054b87045981c431c70d::server:6262b97dea29d5fbd9af2decab5a1695 \
  INSTALL_K3S_VERSION="v1.29.3+k3s1" \
  sh -s - --node-name monitoring \
  --node-label "node-role=monitoring" \
  --node-taint "dedicated=monitoring:NoSchedule"
```

#### Résultat final du cluster

```
NAME        STATUS   ROLES                  AGE    VERSION         INTERNAL-IP
kube-1      Ready    control-plane,master   51m    v1.29.3+k3s1    10.1.24.122
kube-2      Ready    <none>                 8m     v1.29.3+k3s1    10.1.24.126
ingress     Ready    <none>                 103s   v1.29.3+k3s1    10.1.24.74
monitoring  Ready    <none>                 63s    v1.29.3+k3s1    10.1.24.68
```

---

## Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `dnf install curl` échoue | `curl-minimal` préinstallé sur AL2023, conflit avec `curl` | Supprimer `curl` de la liste, utiliser `--skip-broken` |
| `dnf update -y` échoue | Même conflit curl-minimal | Supprimer `dnf update` du script |
| Binaires kubectx/kubens cassés | Script téléchargeait `x86_64` sur une VM `aarch64` | Auto-détection avec `uname -m`, mapping `aarch64→arm64` |
| `scp: No such file or directory` | Chemin relatif incorrect depuis le Mac | Utiliser le chemin absolu ou `cd kubequest` d'abord |
| K3s agent 401 Unauthorized | Token copié avec `k` minuscule au lieu de `K` majuscule | Relire le token depuis `node-token` et copier exactement |
| kube-2 absent de `kubectl get nodes` | Même erreur de casse sur le token | Désinstaller l'agent, réinstaller avec le token exact |

---

## Structure du projet

```
kubequest/
├── terraform/
│   ├── main.tf                     # Data sources AWS pour les 4 VMs Epitech
│   ├── variables.tf                # Région eu-west-1, IDs des instances
│   ├── outputs.tf                  # IPs, commandes SSH
│   └── terraform.tfvars.example
├── cluster/
│   └── k3s-install.sh              # Script d'install K3s (master/worker/ingress/monitoring)
├── infra/
│   └── base/
│       ├── nginx-ingress/
│       │   └── values.yaml         # nodeSelector + toleration nœud ingress
│       └── monitoring/
│           ├── values-prometheus.yaml  # kube-prometheus-stack sur nœud monitoring
│           └── values-loki.yaml        # Loki sur nœud monitoring
├── app/
│   └── helm-chart/                 # Chart Helm pour l'application Laravel
│       ├── Chart.yaml
│       ├── values.yaml             # 2 replicas, HPA, PodAntiAffinity, MySQL
│       └── templates/
│           ├── deployment.yaml
│           ├── hpa.yaml
│           └── db-backup-cronjob.yaml
└── scripts/
    ├── full-deploy.sh              # Déploiement complet depuis zéro
    ├── stress-test.sh              # Test de charge pour déclencher l'HPA
    └── broken-deploy.sh            # Démo rollback avec Helm
```

---

## Prochaines étapes

- [ ] Copier le projet sur kube-1 via `scp`
- [ ] Déployer **nginx-ingress** sur le nœud `ingress`
- [ ] Déployer **kube-prometheus-stack + Grafana** sur le nœud `monitoring`
- [ ] Déployer **Loki** sur le nœud `monitoring`
- [ ] Déployer le **Kubernetes Dashboard**
- [ ] Builder et pusher l'image Docker de l'application Laravel
- [ ] Déployer l'application via le **Helm chart**
- [ ] Configurer les **Ingress** (règles de routage HTTP)
- [ ] Phase sécurité : OPA, Dex + oauth2-proxy

---

## Commandes utiles

```bash
# État du cluster (depuis kube-1)
kubectl get nodes -o wide
kubectl get pods -A

# Logs d'un pod
kubectl logs -n <namespace> <pod-name> --tail=50

# Re-vérifier le token après redémarrage des VMs
sudo cat /var/lib/rancher/k3s/server/node-token

# SSH sur les nœuds (depuis le Mac)
ssh -i ~/.ssh/kubequest.pem ec2-user@<IP_PUBLIQUE>

# kube-1 (control plane)
ssh -i ~/.ssh/kubequest.pem ec2-user@52.211.176.178

# kube-2
ssh -i ~/.ssh/kubequest.pem ec2-user@ec2-34-242-154-125.eu-west-1.compute.amazonaws.com
```
