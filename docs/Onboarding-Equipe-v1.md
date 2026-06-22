# KubeQuest — Prise en main pour l'équipe

> Pour celles et ceux qui rejoignent le projet sans background infra/DevOps.
> Objectif : comprendre ce qu'on fait, le vocabulaire, et comment contribuer.
> Version 1.

---

## 1. Le projet en 30 secondes

On déploie une petite application web (un compteur, en PHP/Laravel) sur un
**cluster Kubernetes** hébergé sur AWS. L'intérêt du projet n'est pas l'app
(elle est volontairement simple), mais **toute la machinerie autour** :
comment on héberge, surveille, sécurise et met à jour une app de façon
automatisée et professionnelle.

Pense à un restaurant : le plat (l'app) est simple, mais on construit toute
la cuisine, le service, la gestion des stocks et la sécurité autour.

---

## 2. Le vocabulaire en 2 minutes (avec analogies)

| Terme | C'est quoi, simplement |
|-------|------------------------|
| **Container** | Une app empaquetée avec tout ce qu'il lui faut pour tourner. Comme une boite de plat préparé : tu la réchauffes n'importe où, ça marche pareil. |
| **Image Docker** | Le "moule" qui sert à fabriquer un container. On la stocke sur Docker Hub (un dépôt d'images). |
| **Kubernetes (K8s)** | Le chef d'orchestre. Il lance les containers, les redémarre s'ils tombent, les répartit sur les serveurs, les met à l'échelle. On utilise **K3s**, une version légère. |
| **Pod** | La plus petite unité que K8s gère : un (ou quelques) container(s) qui tournent ensemble. |
| **Node / Nœud** | Une machine (serveur) du cluster. On en a 4. |
| **Helm** | Un "installateur" d'apps pour Kubernetes, avec des variables. Comme un template Word qu'on remplit. |
| **Kustomize** | Permet d'avoir une config de base et de la modifier par environnement (staging vs production) sans tout réécrire. |
| **Ingress** | Le standard d'accueil : il reçoit le trafic web et le route vers la bonne app selon l'URL. |
| **GitOps** | Principe clé : **Git est la télécommande du cluster**. On ne touche jamais au cluster à la main, on modifie Git et un robot applique. |
| **ArgoCD** | Le robot GitOps. Il compare en permanence "ce que dit Git" et "ce qui tourne", et réconcilie. |
| **Monitoring** | Prometheus (métriques) + Grafana (graphiques) + Loki (logs). Pour voir ce qui se passe. |

---

## 3. L'architecture (l'image mentale)

4 serveurs (VMs) sur AWS, chacun avec un rôle :

| Serveur | Rôle |
|---------|------|
| **kube-1** | Le cerveau du cluster (control-plane) + fait tourner des apps. Point d'entrée stable (IP fixe). |
| **kube-2** | Serveur de calcul supplémentaire (fait tourner des apps). |
| **ingress** | La porte d'entrée web : reçoit le trafic et le route. |
| **monitoring** | La salle de surveillance : Prometheus, Grafana, Loki. |

Le trafic d'un visiteur :
```
Navigateur -> IP d'entree (kube-1) -> ingress (nginx) -> le bon pod de l'app -> base de donnees MySQL
```

---

## 4. Comment un changement arrive en production (le cycle GitOps)

C'est LE point à comprendre. On ne déploie jamais à la main. On a 2 environnements :

```
On modifie le code ou la config
        |
   git push sur la branche  main
        |
   STAGING se met a jour TOUT SEUL  (environnement de test)
        |
   On verifie que tout va bien sur staging
        |
   On "promeut" : on fusionne main -> prod
        |
   PRODUCTION se met a jour (apres validation manuelle dans ArgoCD)
```

- **main = staging** : déploiement automatique, c'est le bac à sable.
- **prod (branche) = production** : déploiement validé à la main, c'est le sérieux.

Règle d'or : **un changement passe toujours par staging avant la prod.**

---

## 5. Comment participer (tes points d'entrée)

### Étape 0 : avoir les accès
- Accès au repo GitHub `tcisse/kubequest`.
- (Si tu dois toucher au cluster) la clé SSH `kubequest.pem` et l'IP de kube-1.
- Demande à Tairou.

### Où se trouve quoi
| Tu veux toucher... | Va dans... |
|--------------------|-----------|
| Le code de l'app | `sample-app-master/` (Laravel/PHP) |
| La config de déploiement de l'app | `app/helm-chart/` et `app/kustomize/overlays/` |
| L'infra (monitoring, ingress, sécurité) | `infra/base/` |
| La doc | `docs/` |

### Ton premier changement (sans risque)
1. Crée une branche : `git checkout -b ma-feature`
2. Fais ta modif.
3. Push + ouvre une Pull Request sur GitHub.
4. On review ensemble avant de merger sur `main`.
5. Une fois sur `main`, staging se déploie tout seul -> tu vois ton changement.

> Tu ne peux rien casser en prod en passant par une PR : la prod demande
> toujours une validation manuelle.

---

## 6. Les règles d'or (pour ne rien casser)

1. **Jamais de modif directe sur le cluster** (`kubectl edit`...). On passe par Git.
2. **Toujours via une Pull Request**, jamais de push direct sur `main` sans review.
3. **Staging d'abord, prod ensuite.**
4. En cas de doute ou de blocage : **on s'arrête et on demande**, on ne bricole pas.

---

## 7. Pour aller plus loin

| Sujet | Document |
|-------|----------|
| Lancer / utiliser le projet | `docs/Demo.md` |
| Déployer un changement de code | `docs/Deploiement-App-v1.md` |
| Changer le domaine de l'app | `docs/Changer-Domaine-v2.md` |
| Comprendre les concepts en profondeur | `Fiche-Revision-v1.md` (à la racine) |

Bienvenue dans le projet. Commence par lire ce doc, demande tes accès, et
fais un premier petit changement via une PR pour te familiariser avec le flux.
