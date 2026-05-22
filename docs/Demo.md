# KubeQuest — Guide de Démo

---

## Prérequis (depuis ton Mac)

Vérifier que `/etc/hosts` contient bien :
```
108.130.65.49  app.kubequest.local grafana.kubequest.local dashboard.kubequest.local
```

> L'IP peut avoir changé après redémarrage des VMs — vérifier l'IP publique du nœud `ingress`.

---

## 1. Connexion au cluster

```bash
ssh -i ~/.ssh/kubequest.pem ec2-user@<IP_PUBLIQUE_KUBE-1>
```

```bash
# Vérifier que les 4 noeuds sont Ready
kubectl get nodes -o wide

# Vérifier tous les pods
kubectl get pods -A

# Vérifier les Helm releases
helm list -A
```

---

## 2. Montrer l'application

Ouvrir dans le navigateur : `http://app.kubequest.local`

```bash
# Tester l'API Laravel
curl http://app.kubequest.local/api/counter/count
curl http://app.kubequest.local/api/counter/add
```

---

## 3. Montrer Grafana

Ouvrir : `http://grafana.kubequest.local`
Login : `admin` / `changeme-in-secret`

- Montrer les dashboards Prometheus (CPU, RAM, pods)
- Montrer les logs via Loki (Explore → Loki)

---

## 4. Montrer le Kubernetes Dashboard

```bash
# Générer un token (valable 24h)
kubectl -n kubernetes-dashboard create token dashboard-admin --duration=24h
```

Ouvrir : `https://dashboard.kubequest.local` → accepter le warning TLS → coller le token

---

## 5. Démo HPA — Autoscaling

```bash
# Terminal 1 — surveiller les pods
watch kubectl get pods -n kubequest

# Terminal 2 — surveiller le HPA
watch kubectl get hpa -n kubequest
```

Depuis kube-1, lancer le stress test :
```bash
./scripts/stress-test.sh http://app.kubequest.local 50 10000
```

> Les pods passent de 2 à max 5 replicas automatiquement quand le CPU dépasse 70%.

---

## 6. Démo Rollback Helm

```bash
./scripts/broken-deploy.sh staging
```

Ce que ça fait automatiquement :
1. Déploie une image inexistante → pods en `ErrImagePull`
2. Montre l'erreur avec `kubectl describe`
3. Fait un `helm rollback` → retour à la version stable
4. Affiche l'historique des révisions Helm

---

## Commandes utiles en cas de problème

```bash
# Re-vérifier le token K3s après redémarrage
sudo cat /var/lib/rancher/k3s/server/node-token

# Logs d'un pod en erreur
kubectl logs -n kubequest <pod-name> --tail=50

# Restart un déploiement
kubectl rollout restart deployment -n kubequest kubequest-app
```
