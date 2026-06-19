# KubeQuest — Fiche de révision soutenance

> Version 1. Ordre = ordre de présentation conseillé. Chaque section : ce que c'est / pourquoi / dans mon code / question piège.

---

## 0. Pitch d'ouverture (30 sec)

> "J'ai déployé un cluster Kubernetes production-grade sur AWS : 4 nœuds, une app Laravel packagée en Helm, déployée en GitOps via ArgoCD, avec monitoring (Prometheus/Grafana/Loki), sécurité (OPA Gatekeeper, auth OIDC Dex), et les best practices K8s (probes, HPA, anti-affinité, backups)."

---

## 1. K3s vs Kubernetes

- **K3s** = distribution K8s légère (Rancher), un binaire, API 100% conforme.
- etcd remplacé par SQLite (mono-master), traefik désactivé pour mettre nginx.
- **Choix :** légèreté sur 4 petites VMs, install en 1 commande.

**Q : Pourquoi K3s ?** → Léger, API identique, pragmatique. Pas un raccourci.

---

## 2. Architecture nœuds — taints / tolerations / nodeSelector

| Nœud | Rôle | Taint |
|------|------|-------|
| kube-1 | control-plane + worker | — |
| kube-2 | worker | — |
| ingress | nginx-ingress | `dedicated=ingress:NoSchedule` |
| monitoring | Prometheus/Grafana/Loki | `dedicated=monitoring:NoSchedule` |

- **Taint** = le nœud repousse les pods (sauf ceux qui tolèrent). Côté nœud.
- **Toleration** = le pod a le droit d'aller sur un nœud taché. Côté pod.
- **nodeSelector** = le pod choisit son nœud via un label.

**Q : Taint vs nodeSelector ?** → Taint repousse, nodeSelector attire. Les deux = isolation garantie.

---

## 3. Helm vs Kustomize (LA question garantie)

- **Helm** = templating + packaging. Mon app Laravel = chart, avec `values.yaml`, conditions, sous-chart MySQL Bitnami.
- **Kustomize** = patching sans template. `base` + `overlays` (staging/production).

**Pourquoi les deux ?** Helm pour l'app (logique + dépendance DB), Kustomize pour le multi-env GitOps (ArgoCD lit les overlays).

**Q : Pourquoi pas tout Helm ?** → Kustomize natif kubectl, simple pour patcher des envs, lu par ArgoCD. Et le sujet demande de démontrer les deux.

---

## 4. GitOps + ArgoCD

- **Principe :** Git = source unique de vérité. On push sur Git, ArgoCD synchronise le cluster.
- ArgoCD surveille `app/kustomize/overlays/production` sur `main`.
- **Production = sync MANUELLE** (sécurité), staging = auto-sync.
- Détecte le *drift* (cluster ≠ Git) → self-heal ou alerte.

**Q : Si on modifie le cluster à la main ?** → ArgoCD détecte le drift et recorrige vers l'état Git.

**À VÉRIFIER avant démo :** le repo `github.com/tcisse/kubequest.git` doit exister et être à jour.

---

## 5. OPA Gatekeeper (validating webhook)

- **Admission controller :** chaque `kubectl apply` est validé AVANT création. Viole une règle → rejeté.
- **ConstraintTemplate** = la logique en **Rego**. **Constraint** = son application.
- Mes règles : pas de container `privileged`, labels obligatoires, requests/limits obligatoires.

**Q : Validating vs Mutating webhook ?** → Validating accepte/refuse. Mutating modifie la requête (ex: injecter sidecar). Moi = validating.
**Q : Rego ?** → Langage de policy déclaratif d'OPA.

**Démo forte :** déployer un pod `privileged` en live → refusé.

---

## 6. Best practices K8s

| Best practice | Détail |
|---------------|--------|
| Requests + Limits | cpu 100m/500m, mem 256Mi/512Mi |
| Liveness + Readiness | `/health` port 80 |
| Secrets | objet Secret + `envFrom.secretRef` |
| Redondance | 2 replicas + **podAntiAffinity** (pods sur nœuds différents) |
| Persistent storage | PVC MySQL 5Gi |
| Backup | CronJob mysqldump, 2h du matin, rétention 7j |

**Q : Requests vs Limits ?** → Requests = réservé/garanti par le scheduler. Limits = plafond max (CPU throttle / RAM OOMKill).
**Q : Liveness vs Readiness ?** → Liveness mort = pod redémarré. Readiness KO = pod retiré du service, pas tué.
**Q : maxUnavailable: 0 ?** → Zero-downtime : on ajoute un pod (`maxSurge: 1`) avant d'en retirer.

---

## 7. HPA — auto-scaling

- 2 à 5 replicas, scale si CPU > 70% ou RAM > 80%.
- Lit metrics-server, compare au seuil, ajuste les replicas.
- Si HPA actif, le `replicas` du Deployment est ignoré.

**Démo :** `stress-test.sh` → CPU monte → pods créés. Montrer `kubectl get hpa -w`.

---

## 8. Démo rollback (obligatoire, point 4 du sujet)

1. Note la révision Helm actuelle.
2. Déploie une image inexistante → `ErrImagePull`.
3. Montre l'erreur (`kubectl describe`).
4. `helm rollback` vers la révision précédente.

**Q : Helm rollback vs GitOps ?** → Helm garde un historique de révisions. En GitOps : `git revert` + resync ArgoCD.

---

## 9. Auth — Dex + oauth2-proxy

- **Dex** = fournisseur d'identité OIDC. Pont entre provider externe (GitHub/Google) et le cluster.
- **oauth2-proxy** = sentinelle devant les apps (Grafana, Dashboard). Pas de token → redirigé vers Dex.

**Q : OIDC ?** → OpenID Connect, couche d'identité sur OAuth2. Dex émet des JWT vérifiés par les apps.

---

## 10. Observabilité

- **Prometheus** : scrape les métriques (pull).
- **Grafana** : dashboards.
- **Loki** : logs, indexe par labels (pas par contenu) → léger.
- Tout sur le nœud `monitoring` dédié.

---

## ⚠️ Limites à ASSUMER (ne pas cacher)

1. **Node-token K3s en clair dans le README** → devrait être un secret. "Je sais, à retirer du repo."
2. **Secrets app en clair dans values.yaml** → vraie solution : Sealed Secrets / SOPS / External Secrets.
3. **Un seul control-plane** → contrainte Epitech (4 VMs fixes). Pas de HA control-plane.

> Un jury respecte "je connais la limite" plus que "je n'avais pas vu".

---

## Checklist pré-démo

- [ ] Cluster frais démarré, 4 nœuds `Ready`
- [ ] Repo Git à jour et accessible par ArgoCD
- [ ] Node-token re-vérifié (sensible à la casse, K majuscule)
- [ ] Scripts testés : `full-deploy.sh`, `stress-test.sh`, `broken-deploy.sh`
- [ ] Pod `privileged` de test prêt pour la démo OPA
