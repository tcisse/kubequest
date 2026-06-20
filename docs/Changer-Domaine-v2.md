# Changer le domaine de l'application

> Cas d'usage : faire passer l'app de `app.kubequest.local` vers `app2.kubequest.local`.
> Version 2 — APP_URL est maintenant derive de ingress.host (source unique).

---

## Ce qui a change depuis la v1

Avant (v1), le domaine etait defini a 2 endroits par fichier :
`ingress.host` (routage) ET `app.env.APP_URL` (cosmetique Laravel).
On pouvait changer l'un sans l'autre -> 404 nginx.

Maintenant, `APP_URL` est **derive automatiquement** de `ingress.host` dans
`app/helm-chart/templates/deployment.yaml` :

```yaml
- name: APP_URL
  value: "{{ if .Values.ingress.tls }}https{{ else }}http{{ end }}://{{ .Values.ingress.host }}"
```

=> Le domaine se change a **UNE SEULE LIGNE, dans UN SEUL FICHIER** par environnement.

---

## Le seul endroit a modifier

| Environnement | Fichier | Valeur |
|---------------|---------|--------|
| production | `app/kustomize/overlays/production/values.yaml` | `ingress.host` |
| staging | `app/kustomize/overlays/staging/values.yaml` | `ingress.host` |

`APP_URL` n'est plus a toucher : il suit `ingress.host`.
Le schema (http/https) suit automatiquement la presence de `ingress.tls`.

---

## Procedure (GitOps)

### 1. Editer la seule ligne

Dans `app/kustomize/overlays/production/values.yaml` :

```yaml
ingress:
  host: app2.kubequest.local      # <= seule modification
```

### 2. Commit + push

```bash
git add app/kustomize/overlays/production/values.yaml
git commit -m "feat: route app via app2.kubequest.local"
git push origin main
```

### 3. Synchroniser dans ArgoCD

- L'app `kubequest-app-production` passe en OutOfSync.
- Cliquer SYNC (prod = sync manuelle).
- L'Ingress est recree avec le host `app2.kubequest.local`, et le pod
  recoit APP_URL=`http://app2.kubequest.local` automatiquement.

### 4. DNS local (sur le Mac)

```bash
sudo sed -i '' '/kubequest.local/d' /etc/hosts
sudo sh -c 'echo "52.211.176.178 cisse.kubequest.local app2.kubequest.local grafana.kubequest.local dashboard.kubequest.local argocd.kubequest.local" >> /etc/hosts'
```

> `52.211.176.178` = Elastic IP de kube-1 (stable, ne change pas au reboot).
> Le trafic HTTP est route vers l'ingress via K3s ServiceLB (klipper).

### 5. Verifier

```bash
# Le host de l'ingress doit etre app2
kubectl -n kubequest-production get ingress -o jsonpath='{.items[0].spec.rules[0].host}'; echo

# Test
curl -s http://app2.kubequest.local/api/counter/count
```

---

## Methode rapide (impérative, plan B)

```bash
helm upgrade kubequest-app ./app/helm-chart \
  -n kubequest-production \
  --reuse-values \
  --set ingress.host=app2.kubequest.local

# puis /etc/hosts + curl
```

> En GitOps, toujours passer par Git : un sync ArgoCD ecraserait un changement impératif.

---

## Pieges a anticiper

| Piege | Detail |
|-------|--------|
| Confondre host et APP_URL | RESOLU en v2 : APP_URL est derive de ingress.host, on ne touche plus qu'a une ligne. |
| L'ancien domaine meurt | Une seule regle `host`. L'ancien renvoie 404 apres le switch. |
| DNS local obligatoire | Le nouveau host doit etre dans `/etc/hosts` -> Elastic IP de kube-1. |
| ArgoCD doit suivre main | Le commit doit etre sur `main` (ArgoCD ne surveille que main). |

---

## Verifs utiles

```bash
# Host actuel de l'ingress
kubectl get ingress -n kubequest-production -o jsonpath='{.items[0].spec.rules[0].host}'; echo

# APP_URL effectif dans le pod (doit matcher le host)
kubectl -n kubequest-production exec deploy/kubequest-app -c app -- printenv APP_URL
```
