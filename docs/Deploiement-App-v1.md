# Deployer un changement applicatif

> Pipeline : Code Laravel -> build image Docker -> push Docker Hub -> K8s pull -> rolling update
> Version 1.

---

## Vue d'ensemble

```
Code Laravel  →  build image (ARM64)  →  push Docker Hub  →  bump tag dans Git  →  ArgoCD sync  →  rolling update
```

Image : `cissetaher/kubequest-app`
Nodes : ARM64 (aarch64 / Graviton) => l'image DOIT etre buildee en `linux/arm64`.

---

## 1. Modifier le code

Edition dans `sample-app-master/` (l'app Laravel).

---

## 2. Builder l'image en ARM64

Depuis `sample-app-master/` :

```bash
docker build --platform linux/arm64 -t cissetaher/kubequest-app:v2 .
```

> Utiliser un tag versionne (`v2`, `v1.1`, ou le commit SHA), JAMAIS `latest`.
> Un tag immuable est ce qui permet a ArgoCD de detecter le changement.

---

## 3. Pusher sur Docker Hub

```bash
# Une seule fois : se connecter
docker login

docker push cissetaher/kubequest-app:v2
```

---

## 4. Deployer

### Voie GitOps (recommandee)

Editer le tag dans `app/kustomize/overlays/production/values.yaml` :

```yaml
app:
  image:
    tag: "v2"      # etait "latest"
```

Commit + push :

```bash
git add app/kustomize/overlays/production/values.yaml
git commit -m "Deploy app v2"
git push origin main
```

Puis dans ArgoCD (`kubequest-app-production`) : REFRESH puis SYNC.
ArgoCD applique le nouveau Deployment, K8s fait un rolling update.

### Voie rapide (impérative, sans GitOps)

Seulement si le tag reste `latest` avec `pullPolicy: Always` :

```bash
kubectl -n kubequest-production rollout restart deployment kubequest-app
```

> Attention : non tracable par ArgoCD. Si l'app est en auto-sync, ArgoCD
> peut ecraser ce changement. En GitOps, toujours passer par Git.

---

## 5. (Si besoin) Migration de base de donnees

Si le changement inclut une migration :

```bash
kubectl -n kubequest-production exec deploy/kubequest-app -c app -- php artisan migrate --force
```

---

## 6. Verifier

```bash
# Suivre le rollout
kubectl -n kubequest-production rollout status deployment kubequest-app

# Tester l'app
curl -s http://app.kubequest.local/api/counter/count
```

---

## Notes importantes

| Point | Detail |
|-------|--------|
| ARM64 obligatoire | `--platform linux/arm64`, sinon `exec format error` sur les nodes Graviton. |
| Tag immuable | `latest` casse le GitOps (ArgoCD ne voit aucun changement). Utiliser un tag versionne. |
| Zero-downtime | Le Deployment est en `maxSurge: 1` / `maxUnavailable: 0` : les nouveaux pods montent avant que les anciens partent. |
| Rollback | `helm rollback` (impératif) ou `git revert` + sync (GitOps). |

---

## Rollback rapide en cas de probleme

```bash
# Voie GitOps : revenir au commit precedent
git revert HEAD
git push origin main
# puis SYNC dans ArgoCD

# Voie Helm (si deploiement direct)
helm rollback kubequest-app -n kubequest-production
```
