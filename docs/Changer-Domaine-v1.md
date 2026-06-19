# Changer le domaine de l'application

> Cas d'usage : faire passer l'app de `app.kubequest.local` vers `backend.kubequest.local`.
> Version 1.

---

## Où vit le domaine

Source de vérité unique :

```
app/kustomize/overlays/<env>/values.yaml  →  ingress.host
```

Cette valeur alimente le template `app/helm-chart/templates/ingress.yaml` :

```yaml
rules:
  - host: {{ .Values.ingress.host }}   # la regle Host de l'Ingress nginx
```

C'est cette regle Host qui fait tout le routage HTTP.

`app.env.APP_URL` (meme fichier) est cosmetique : Laravel s'en sert pour generer
des URLs absolues. A changer pour la coherence, mais ca ne touche pas au routage.

---

## Methode A — GitOps via ArgoCD (recommandee)

> Principe : on ne touche pas le cluster a la main. On change Git, ArgoCD reconcilie.

### 1. Editer la valeur

Dans `app/kustomize/overlays/production/values.yaml` :

```yaml
ingress:
  enabled: true
  className: nginx
  host: backend.kubequest.local      # <= etait app.kubequest.local

app:
  env:
    APP_URL: "http://backend.kubequest.local"   # coherence Laravel
```

### 2. Commit + push

```bash
git add app/kustomize/overlays/production/values.yaml
git commit -m "Change app domain to backend.kubequest.local"
git push origin main
```

### 3. Synchroniser dans ArgoCD

- L'app `kubequest-app-production` passe en **OutOfSync** (Git differe du cluster).
- Cliquer **SYNC** dans l'UI ArgoCD (prod = sync manuelle).
- L'objet Ingress est recree avec le nouveau host.

### 4. DNS local (sur le Mac)

```bash
sudo sed -i '' '/kubequest.local/d' /etc/hosts
sudo sh -c 'echo "54.216.48.170  backend.kubequest.local grafana.kubequest.local dashboard.kubequest.local argocd.kubequest.local" >> /etc/hosts'
```

> `54.216.48.170` = IP publique du noeud ingress (private `10.1.24.74`).
> Verifier l'IP apres chaque redemarrage des VMs.

### 5. Verifier

```bash
curl -s http://backend.kubequest.local/api/counter/count
# => {"value":"..."}  attendu
```

---

## Methode B — Imperative via Helm (plan B, si GitOps indispo)

```bash
helm upgrade kubequest-app ./app/helm-chart \
  -n kubequest-production \
  --reuse-values \
  --set ingress.host=backend.kubequest.local

# puis /etc/hosts + curl (etapes 4 et 5 ci-dessus)
```

> ATTENTION : si ArgoCD est en auto-sync sur cet env, il ECRASERA ce changement
> au prochain cycle (il remet l'etat Git). En GitOps, toujours passer par Git.

---

## Pieges a anticiper

| Piege | Detail |
|-------|--------|
| L'ancien domaine meurt | Une seule regle `host`. `app.kubequest.local` renvoie 404 apres le switch. Pour garder les deux, il faut deux entrees host (evolution du template). |
| DNS local obligatoire | `backend.kubequest.local` n'existe nulle part tant qu'il n'est pas dans `/etc/hosts`. |
| IP ingress volatile | L'IP publique change a chaque reboot des VMs. La private (`10.1.24.74`) est stable. |
| ArgoCD Sync Unknown | Les overlays inflatent des charts Helm => ArgoCD a besoin de `kustomize.buildOptions: --enable-helm` dans l'argocd-cm, sinon le build echoue. |

---

## Verifs utiles

```bash
# Voir l'Ingress et son host actuel
kubectl get ingress -n kubequest-production -o wide

# Detail de la regle host
kubectl get ingress -n kubequest-production -o jsonpath='{.items[0].spec.rules[0].host}'; echo
```
