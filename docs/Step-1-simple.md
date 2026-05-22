# Step 1 — En simple : on a déployé les services

## C'était quoi le but ?

Le cluster existe, maintenant on y installe tout ce qui doit tourner dessus.

---

## Ce qu'on a installé et où

| Service | Rôle | Machine | Accès |
|---------|------|---------|-------|
| **nginx-ingress** | Reçoit le trafic web et l'envoie au bon service | `ingress` | — |
| **Prometheus** | Collecte les métriques (CPU, RAM...) de tout le cluster | `monitoring` | — |
| **Grafana** | Affiche les métriques et logs dans des beaux dashboards | `monitoring` | `http://grafana.kubequest.local` |
| **Loki** | Collecte les logs de tous les pods | `monitoring` | — |
| **Kubernetes Dashboard** | Interface web pour gérer le cluster sans kubectl | `monitoring` | `https://dashboard.kubequest.local` |
| **App Laravel** | L'application du projet | `kube-1` + `kube-2` | `http://app.kubequest.local` |

---

## Comment on accède depuis son Mac

Ajouter dans `/etc/hosts` :
```
108.130.65.49  app.kubequest.local grafana.kubequest.local dashboard.kubequest.local
```

`108.130.65.49` = IP publique du nœud `ingress` qui reçoit tout.

---

## Les points importants à retenir

### nginx-ingress
C'est le point d'entrée de tout le trafic. On l'a configuré avec `hostNetwork: true` pour qu'il écoute directement sur le port 80/443 de la machine `ingress`.

Sans ça, les requêtes depuis l'extérieur n'arrivaient pas. Avec ça, tout passe.

### Grafana
- Login : `admin` / `changeme-in-secret`
- Datasources branchées : Prometheus (métriques) + Loki (logs)

### Kubernetes Dashboard
- Accès : `https://dashboard.kubequest.local`
- Connexion avec un **Bearer token** (à générer avec la commande ci-dessous)
- Faut accepter le warning du certificat (certificat auto-signé, pas reconnu par le navigateur, c'est normal)

```bash
# Générer un token d'accès (valable 24h)
kubectl -n kubernetes-dashboard create token dashboard-admin --duration=24h
```

### Application Laravel
Deux routes API fonctionnelles :
- `GET /api/counter/count` → retourne la valeur du compteur
- `GET /api/counter/add` → incrémente le compteur

---

## Les galères qu'on a eues

**Tout retournait `000` depuis le Mac**
Le portier nginx n'écoutait pas sur la bonne machine. Fix : activer `hostNetwork: true`.

**Grafana plantait au démarrage**
Deux services essayaient d'être la source de données "par défaut" en même temps (Prometheus et Loki). Fix : dire explicitement à Loki qu'il n'est pas le défaut.

**Dashboard refusait le token (401)**
Le dashboard v7 a besoin de HTTPS pour fonctionner correctement (question de sécurité des cookies). On était en HTTP. Fix : ajouter un certificat auto-signé pour activer HTTPS.

**Le chart Helm du dashboard était introuvable**
GitHub a désactivé l'hébergement du chart. Fix : télécharger le fichier directement depuis les releases GitHub.
