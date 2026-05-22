# Step 0 — En simple : on a monté le cluster

## C'était quoi le but ?

On avait 4 serveurs sur AWS. L'objectif c'était de les relier pour former un seul cluster Kubernetes.

---

## Les 4 machines et leurs rôles

| Machine | Rôle |
|---------|------|
| `kube-1` | Le cerveau du cluster + fait tourner des apps |
| `kube-2` | Fait tourner des apps |
| `ingress` | Le portier : tout le trafic web entre par là |
| `monitoring` | Réservé aux outils d'observation (Grafana, logs...) |

---

## Ce qu'on a fait, étape par étape

**1. Installer K3s sur kube-1**
K3s c'est une version légère de Kubernetes. On l'a installé sur kube-1 qui devient le "cerveau" (control plane) du cluster.

**2. Récupérer le token de jonction**
K3s génère un mot de passe secret. Les autres machines en ont besoin pour rejoindre le cluster.

**3. Faire rejoindre les 3 autres machines**
On a exécuté une commande sur chaque machine avec ce token. Elles se sont connectées à kube-1 et font maintenant partie du cluster.

**4. Configurer les rôles**
- `ingress` et `monitoring` ont été marqués "réservés" : seuls leurs services dédiés peuvent s'y déployer
- `kube-1` et `kube-2` peuvent faire tourner n'importe quelle app

---

## Résultat

```
NAME        STATUS
kube-1      Ready  ✅
kube-2      Ready  ✅
ingress     Ready  ✅
monitoring  Ready  ✅
```

4 machines, 1 cluster, tout est prêt pour déployer des services.

---

## Les galères qu'on a eues

- Le token de jonction K3s a un `K` majuscule. Copié en minuscule → les machines refusaient de rejoindre. Fix : copier-coller exact.
- Les VMs sont sur ARM64, pas x86. Certains outils téléchargeaient la mauvaise version. Fix : détecter l'architecture automatiquement.
