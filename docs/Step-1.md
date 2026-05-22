# KubeQuest — Step 1 : Services d'infrastructure

> Déploiement de nginx-ingress, kube-prometheus-stack, Loki et Kubernetes Dashboard.

---

## Ce qui a été déployé

| Service | Namespace | Nœud | Accès |
|---------|-----------|------|-------|
| ingress-nginx | `ingress-nginx` | `ingress` | — |
| kube-prometheus-stack (Grafana + Prometheus + Alertmanager) | `monitoring` | `monitoring` | `http://grafana.kubequest.local` |
| Loki + Promtail | `monitoring` | `monitoring` | — |
| Kubernetes Dashboard | `kubernetes-dashboard` | `monitoring` | `https://dashboard.kubequest.local` |
| Application Laravel | `kubequest` | `kube-1` / `kube-2` | `http://app.kubequest.local` |

---

## 1. nginx-ingress

### Installation

```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values infra/base/nginx-ingress/values.yaml
```

### Configuration clé (`infra/base/nginx-ingress/values.yaml`)

- `hostNetwork: true` + `hostPort.enabled: true` : le contrôleur écoute directement sur les ports 80/443 du nœud `ingress` (IP publique `108.130.65.49`)
- `nodeSelector: node-role: ingress` + tolération `dedicated=ingress:NoSchedule`

> **Pourquoi hostNetwork ?**
> Sans `hostNetwork`, k3s's klipper-lb forwardait le trafic uniquement depuis kube-1/kube-2.
> Avec `hostNetwork`, nginx écoute directement sur le nœud `ingress` dédié.

### Accès externe

Ajouter dans `/etc/hosts` (Mac) :
```
108.130.65.49  dashboard.kubequest.local app.kubequest.local grafana.kubequest.local
```

---

## 2. kube-prometheus-stack (Grafana + Prometheus + Alertmanager)

### Installation

```bash
helm upgrade --install kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring \
  --create-namespace \
  --values infra/base/monitoring/values-prometheus.yaml
```

### Accès Grafana

- URL : `http://grafana.kubequest.local`
- Login : `admin` / `changeme-in-secret`
- Datasources configurées : **Prometheus** (default) + **Loki**

### Problème rencontré : conflit datasource isDefault

**Symptôme :** Grafana en `CrashLoopBackOff` avec l'erreur :
```
Datasource provisioning error: datasource.yaml config is invalid.
Only one datasource per organization can be marked as default
```

**Cause :** Le chart `loki-stack` crée un ConfigMap (`loki-loki-stack`) avec `isDefault: true` pour Loki. Le chart `kube-prometheus-stack` crée aussi Prometheus avec `isDefault: true`. Conflit.

**Fix :**
1. Dans `values-prometheus.yaml` : ajouter `isDefault: false` sur la datasource Loki additionnelle
2. Dans `values-loki.yaml` : ajouter `grafana.sidecar.datasources.defaultDatasourceEnabled: false`
3. Patcher le ConfigMap existant :
```bash
kubectl patch configmap loki-loki-stack -n monitoring --type merge \
  -p '{"data":{"loki-stack-datasource.yaml":"apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  access: proxy\n  url: http://loki:3100\n  version: 1\n  isDefault: false\n"}}'
```

---

## 3. Loki + Promtail

### Installation

```bash
helm upgrade --install loki loki-stack \
  --repo https://grafana.github.io/helm-charts \
  --namespace monitoring \
  --values infra/base/monitoring/values-loki.yaml
```

### Configuration clé (`infra/base/monitoring/values-loki.yaml`)

- Persistence activée (5Gi)
- Grafana désactivé (géré par kube-prometheus-stack)
- `defaultDatasourceEnabled: false` pour éviter le conflit isDefault

---

## 4. Kubernetes Dashboard

### Chart

Le chart officiel (`kubernetes.github.io/dashboard`) n'est plus disponible via GitHub Pages.
**Solution :** Téléchargement direct depuis les GitHub Releases.

```bash
curl -sL https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-7.14.0/kubernetes-dashboard-7.14.0.tgz \
  -o /tmp/kubernetes-dashboard-7.14.0.tgz
```

### Installation

```bash
# Créer namespace + RBAC
kubectl apply -f infra/base/kubernetes-dashboard/namespace.yaml
kubectl apply -f infra/base/kubernetes-dashboard/admin-serviceaccount.yaml

# Déployer le chart
helm upgrade --install kubernetes-dashboard /tmp/kubernetes-dashboard-7.14.0.tgz \
  --namespace kubernetes-dashboard \
  --values infra/base/kubernetes-dashboard/values.yaml
```

### Configuration clé (`infra/base/kubernetes-dashboard/values.yaml`)

- `app.scheduling.nodeSelector: node-role: monitoring` + tolération `dedicated=monitoring:NoSchedule`
- `kong.proxy.http.enabled: true` : active le port 80 sur Kong (nécessaire pour que l'ingress route correctement)
- `app.ingress.tls.enabled: true` avec `secretName: dashboard-tls` : **HTTPS obligatoire** pour les cookies CSRF

### Certificat TLS auto-signé

```bash
# Générer le certificat
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/dashboard.key \
  -out /tmp/dashboard.crt \
  -subj '/CN=dashboard.kubequest.local/O=kubequest' \
  -addext 'subjectAltName=DNS:dashboard.kubequest.local'

# Créer le secret Kubernetes
kubectl create secret tls dashboard-tls \
  --cert=/tmp/dashboard.crt \
  --key=/tmp/dashboard.key \
  -n kubernetes-dashboard
```

### RBAC — ServiceAccount admin

Fichier `infra/base/kubernetes-dashboard/admin-serviceaccount.yaml` :
- ServiceAccount `dashboard-admin` dans `kubernetes-dashboard`
- ClusterRoleBinding vers `cluster-admin`
- Secret de type `kubernetes.io/service-account-token` pour un token permanent

### Récupérer le token d'accès

```bash
# Token permanent (secret)
kubectl get secret dashboard-admin-token -n kubernetes-dashboard \
  -o jsonpath='{.data.token}' | base64 -d

# Token temporaire (24h)
kubectl -n kubernetes-dashboard create token dashboard-admin --duration=24h
```

### Accès

- URL : `https://dashboard.kubequest.local` (accepter le warning certificat auto-signé)
- Méthode : **Bearer token**

### Problème rencontré : 401 Unauthorized

**Symptôme :** Token valide mais dashboard retourne `MSG_LOGIN_UNAUTHORIZED_ERROR`

**Cause :** Dashboard v7 utilise Kong comme API gateway avec protection CSRF.
Les cookies CSRF ont le flag `Secure` et ne fonctionnent pas sur HTTP.

**Fix :** Configurer TLS sur l'ingress (certificat auto-signé suffit) pour que le dashboard soit accessible en HTTPS.

---

## Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `curl http://domain.local` → `000` depuis le Mac | Nginx-ingress sans `hostNetwork`, klipper-lb ne forwardait que sur kube-1/kube-2 | Activer `hostNetwork: true` + `hostPort.enabled: true` sur nginx-ingress |
| Grafana `CrashLoopBackOff` | Deux datasources `isDefault: true` (Prometheus + Loki) | `isDefault: false` sur Loki dans les deux charts |
| Dashboard 401 avec token valide | Dashboard v7 exige HTTPS pour les cookies CSRF | Certificat auto-signé + TLS sur l'ingress |
| Chart dashboard introuvable via helm repo | GitHub Pages de `kubernetes/dashboard` désactivé | Téléchargement direct du `.tgz` depuis GitHub Releases |
| Ingress dashboard → port 80 vide (`()`) | `kong.proxy.http.enabled: false` par défaut | Activer `kong.proxy.http.enabled: true` dans les values |

---

## Vérification finale

```bash
# Depuis le Mac (après /etc/hosts)
curl -s -o /dev/null -w '%{http_code}\n' http://app.kubequest.local        # 200
curl -s -o /dev/null -w '%{http_code}\n' http://grafana.kubequest.local    # 302 (login)
curl -sk -o /dev/null -w '%{http_code}\n' https://dashboard.kubequest.local # 200

# État du cluster
kubectl get pods -A
kubectl get ingress -A
helm list -A
```

## État des Helm releases

```
NAME                    NAMESPACE               REVISION  STATUS    CHART
ingress-nginx           ingress-nginx           2         deployed  ingress-nginx-4.15.1
kube-prometheus-stack   monitoring              3         deployed  kube-prometheus-stack-82.14.1
loki                    monitoring              2         deployed  loki-stack-2.10.3
kubernetes-dashboard    kubernetes-dashboard    4         deployed  kubernetes-dashboard-7.14.0
kubequest-app           kubequest               4         deployed  kubequest-app-0.1.0
```
