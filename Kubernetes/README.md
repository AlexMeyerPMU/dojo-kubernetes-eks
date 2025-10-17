
# Dojo Kubernetes

Votre objectif est de déployer plusieurs applications sur Kubernetes, et d'apprendre un maximum pendant cette session.

## Consignes générales

- **Gardez une trace de vos actions** : créez une documentation en markdown dans ce dépôt, où vous notez les commandes utilisées, les erreurs rencontrées et comment vous les avez résolues.
- **Section "Apprentissages" obligatoire** : pour chaque difficulté, notez :
  - Problème rencontré (et pourquoi il est survenu)
  - Solution apportée (et pourquoi elle fonctionne)
  - Nouveau savoir (et pourquoi il est utile)

---

## 0. Préparer votre environnement

### Pourquoi

Pour pouvoir manipuler Kubernetes en local, il vous faut un cluster local, des outils pour interagir avec lui, et de quoi observer ce qui s'y passe.

### Comment

1. Installez les outils suivants :

  - [minikube](https://minikube.sigs.k8s.io/docs/start/) : pour créer un cluster Kubernetes local
  - [kubectl](https://kubernetes.io/docs/tasks/tools/) : pour piloter Kubernetes en ligne de commande
  - [Docker](https://docs.docker.com/get-docker/) : pour construire et stocker vos images de conteneurs
  - [Helm](https://helm.sh/docs/intro/install/) : pour gérer des applications complexes via des charts
  - [k9s](https://k9scli.io/topics/install/) : pour observer et interagir avec le cluster en mode TUI
  - [stern](https://github.com/stern/stern) : pour suivre les logs de plusieurs pods en même temps
  - [kubens](https://github.com/ahmetb/kubectx#kubens) : pour changer rapidement de namespace dans kubectl
  - [kubectx](https://github.com/ahmetb/kubectx#kubectx) : pour changer rapidement de contexte dans kubectl

2. Vérifiez l'installation de chaque outil avec :

  ```bash
  minikube version
  kubectl version --client
  docker --version
  helm version
  k9s version
  ```

3. Les astuces pour kubernetes :

   ```bash
   alias k='kubectl'
   brew install krew
   k krew install ctx
   k krew install ns
   k ctx minikube
   k ns default
   ```

### Indices

- Suivez les guides d'installation officiels pour chaque outil (liens ci-dessus)

### Vérifications

- [ ] Tous les outils sont installés et fonctionnels
- [ ] Vous pouvez lancer `minikube start` sans erreur
- [ ] Vous pouvez exécuter `kubectl get nodes` et voir le nœud minikube

## 1. Explorer minikube et les bases de Kubernetes

### Pourquoi

Avant de déployer des applications, il est essentiel de comprendre l'état de votre cluster et de manipuler les ressources de base de Kubernetes.

### Comment

Testez les commandes suivantes et observez leur sortie :

- `kubectl get all` : liste toutes les ressources principales du namespace courant
- `kubectl get nodes` : affiche les nœuds du cluster
- `kubectl get namespaces` : liste les namespaces disponibles
- `kubectl config view` : affiche la configuration kubectl
- `kubectl config current-context` : affiche le contexte courant
- `kubectl describe node minikube` : détails sur le nœud minikube
- `kubectl cluster-info` : informations sur le cluster
- `kubectl get events --sort-by='.metadata.creationTimestamp' -A` : derniers événements du cluster dans tous les namespaces
- `kubectl get pods --all-namespaces` : liste tous les pods de tous les namespaces
- `kubectl get pods -o yaml` : affiche la description YAML des pods
- `kubectl explain pods` : documentation sur la ressource Pod

### Indices

- Utilisez l'auto-complétion de kubectl (`kubectl <TAB><TAB>`) pour découvrir d'autres commandes
- Essayez d'explorer avec l'outil `k9s` pour une vue interactive

### Vérifications

- [ ] Vous savez lister les ressources principales du cluster
- [ ] Vous savez afficher les détails d'un nœud ou d'un pod
- [ ] Vous savez trouver le contexte courant et les namespaces


## 2. Déployer le guestbook (Pod)

### Pourquoi

Maintenant que vous savez exécuter une application localement, l'étape suivante est de la déployer sur Kubernetes. Le Pod est l'unité de base d'exécution sur Kubernetes : il permet de lancer un ou plusieurs conteneurs ensemble.

### Comment

1. Créez un fichier `pod.yaml` décrivant un Pod minimal :
  - Donnez-lui un nom
  - Définissez un conteneur avec un nom et une image

2. Déployez le pod

1. Vérifiez son état et ses logs
1. Testez l'accès à l'application (via port-forward)
1. Supprimez le pod si besoin

### Indices

- Essayez de déployer une image qui n'existe pas pour voir le comportement de Kubernetes
- Utilisez l'extension VSCode Kubernetes pour générer des manifests YAML
- Observez ce qui se passe si vous modifiez le nom ou l'image du conteneur

### Vérifications

- [ ] Mon pod est en état "Running" et je peux suivre ses logs
- [ ] J'accède à l'interface web via le port-forward


## 3. Déployer le guestbook (Deployment + Service)

### Pourquoi

Un seul pod, c'est bien, mais si le nœud tombe, votre application n'est plus disponible. Les Deployments permettent de gérer la réplication, la mise à jour sans interruption et la robustesse. Les Services permettent d'accéder à n'importe quel pod via un point d'entrée unique (load balancing interne).

### Comment

1. **Transformez votre pod en Deployment** :
   - Créez un fichier `deployment.yaml` avec un template de pod et un nombre de replicas.
2. **Déployez le Deployment** :
3. **Créez un Service pour exposer l'application** (attention au selector)
4. **Testez l'accès à l'application**
5. **Expérimentez** :
   - Supprimez un pod et observez le redémarrage automatique
   - Modifiez l'image ou le nombre de replicas et observez le rolling update
   - Essayez de casser le service (mauvais label) et observez le résultat

### Indices

- Les labels sont essentiels pour l'association entre Service et Pods
- Le champ `selector` du Service doit correspondre aux labels du template du Deployment
- Utilisez `kubectl describe` pour comprendre le lien entre les ressources

### Vérifications

- [ ] J'accède à une des réplicas via port-forward
- [ ] J'ai listé ou décrit mon Deployment
- [ ] J'accède à l'UI via le port-forward du Service

## 4. Déployer le guestbook (Helm Chart)

### Pourquoi

Helm est le gestionnaire de packages pour Kubernetes. Il permet de déployer facilement des applications complexes avec leurs dépendances, de gérer les versions et de paramétrer les déploiements selon l'environnement.

### Comment

1. **Créez la structure d'un chart Helm**
     - Consultez la [documentation officielle Helm](https://helm.sh/docs/) pour les bonnes pratiques

2. **Modifiez les templates** :
   - Remplacez le contenu de `templates/deployment.yaml` par votre deployment
   - Remplacez le contenu de `templates/service.yaml` par votre service
   - Modifiez `values.yaml` pour paramétrer votre application :

3. **Utilisez les valeurs dans vos templates** :
   - `{{ .Values.replicaCount }}`
   - `{{ .Values.service.port }}`
   - `{{ .Values.image.repository }}`
   - `{{ .Values.image.tag }}`

4. **Déployez avec Helm**

5. **Mettez à jour le déploiement**

### Indices

- Utilisez `helm template` pour prévisualiser les manifests générés
- Les templates Helm utilisent la syntaxe Go template

### Vérifications

- [ ] Mon chart Helm se déploie sans erreur
- [ ] Je peux modifier les paramètres via values.yaml
- [ ] Je peux mettre à jour le déploiement avec helm upgrade

## 5. Ajouter une base de données (Redis Helm Chart)

### Pourquoi

Le guestbook a besoin d'une base de données Redis pour persister les messages. Plutôt que de créer nos propres manifests Redis, nous allons utiliser un chart Helm officiel qui gère la complexité de la configuration et la sécurité.

### Comment

1. **Ajoutez le repository Helm Bitnami**
    - https://artifacthub.io/packages/helm/bitnami/redis

2. **Déployez Redis avec Helm**

3. **Vérifiez le déploiement Redis**

4. **Connectez le guestbook à Redis**
   - Modifiez votre deployment guestbook pour ajouter la variable d'environnement : `REDIS_HOST`

5. **Redéployez le guestbook**

6. **Testez la persistance**
   - Ajoutez un message via l'interface web
   - Redémarrez le pod guestbook
   - Vérifiez que le message est toujours là

### Indices

- Le service Redis s'appelle `redis-master` par défaut avec le chart Bitnami
- Utilisez `kubectl logs` pour diagnostiquer les problèmes de connexion
- La variable d'environnement `REDIS_HOST` doit pointer vers le service Redis

### Vérifications

- [ ] Redis est déployé et fonctionne
- [ ] Le guestbook se connecte à Redis sans erreur
- [ ] Les messages sont persistés entre les redémarrages

## 6. Rendre l'application robuste avec les probes

### Pourquoi

Sans Redis, l'application ne fonctionne pas correctement mais Kubernetes ne le sait pas. Les probes permettent à Kubernetes de vérifier continuellement la santé de vos applications et de prendre des mesures correctives (redémarrage, arrêt du trafic, etc.).

### Comment

1. **Comprenez les types de probes** :
   - **Liveness probe** : vérifie si l'application est vivante (redémarre le pod si échec)
   - **Readiness probe** : vérifie si l'application peut recevoir du trafic
   - **Startup probe** : vérifie si l'application a bien démarré (pour les apps lentes)

2. **Ajoutez des probes à votre deployment**

3. **Déployez sans Redis d'abord**

4. **Observez le comportement**

5. **Testez l'accès**

6. **Remettez Redis en place**

### Indices

- L'endpoint `/healthz` du guestbook retourne 500 si Redis n'est pas accessible
- Les probes échouent si l'application retourne un code d'erreur HTTP (≥400)
- Utilisez `kubectl get events` pour voir les actions de Kubernetes

### Vérifications

- [ ] Mes pods sont "Not Ready" quand Redis est absent
- [ ] L'application redevient accessible automatiquement quand Redis revient
- [ ] Je comprends la différence entre liveness et readiness probes

## 7. Faire monter en charge automatiquement (HPA)

### Pourquoi

Quand la charge augmente, il faut plus de pods pour maintenir les performances. Le Horizontal Pod Autoscaler (HPA) surveille les métriques (CPU, mémoire, métriques custom) et ajuste automatiquement le nombre de replicas.

### Comment

1. **Activez les metrics server** (requis pour HPA)

2. **Ajoutez des resource requests à votre deployment**

3. **Créez un HPA** :

4. **Installez k6 pour les tests de charge**
   - https://k6.io/

5. **Créez un script k6** (`load-test.js`) :
   ```javascript
   import http from 'k6/http';
   import { check } from 'k6';

   export let options = {
     stages: [
       { duration: '1m', target: 100 },
       { duration: '3m', target: 100 },
       { duration: '1m', target: 0 },
     ],
   };

   export default function () {
     let response = http.get('http://localhost:3000');
     check(response, {
       'status is 200': (r) => r.status === 200,
     });
   }
   ```

6. **Lancez le test de charge et observez** :
   ```bash
   # Terminal 1: port-forward
   kubectl port-forward svc/guestbook 3000:3000

   # Terminal 2: surveillance HPA
   kubectl get hpa -w

   # Terminal 3: lancer k6
   k6 run load-test.js
   ```

### Indices

- Le HPA met quelques minutes à réagir et stabiliser
- Utilisez `kubectl top pods` pour voir la consommation des ressources
- Les resource requests sont obligatoires pour que le HPA fonctionne

### Vérifications

- [ ] Le HPA est créé et fonctionne
- [ ] Sous charge, le nombre de pods augmente automatiquement
- [ ] Après la charge, le nombre de pods redescend

## 8. (Optionnel) Charger les secrets depuis External Secrets

### Pourquoi

En production, les secrets (mots de passe, clés API) ne doivent pas être stockés dans le code ou les manifests. External Secrets Operator permet de récupérer des secrets depuis des sources externes (GitHub, AWS, Azure, etc.).

### Comment

1. **Installez External Secrets Operator** [https://charts.external-secrets.io](https://charts.external-secrets.io)

2. **Créez un secret dans GitHub** (ou votre source préférée)

3. **Configurez un SecretStore** :
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: SecretStore
   metadata:
     name: github-secret-store
   spec:
     provider:
       github:
         app_id: "your-app-id"
         installation_id: "your-installation-id"
         private_key_secret_ref:
           name: github-app-key
           key: private-key
   ```

4. **Créez un ExternalSecret** :
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: redis-password
   spec:
     refreshInterval: 1m
     secretStoreRef:
       name: github-secret-store
       kind: SecretStore
     target:
       name: redis-secret
       creationPolicy: Owner
     data:
     - secretKey: password
       remoteRef:
         key: redis-password
   ```

### Vérifications

- [ ] External Secrets Operator est installé et fonctionne
- [ ] Les secrets sont récupérés automatiquement depuis la source externe

## 9. (Optionnel) Stratégies de déploiement avancées

### Blue-Green Deployment

1. **Créez deux versions de votre application** :
   - Version "blue" (actuellement en production)
   - Version "green" (nouvelle version)

2. **Basculez le trafic instantanément** via les labels du service

## 10. (Optionnel) Observer avec Kube-shark

### Pourquoi

Kube-shark permet d'observer le trafic réseau dans votre cluster, utile pour déboguer les problèmes de connectivité.

### Comment

1. **Installez kube-shark** :
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubeshark/kubeshark/main/kubeshark.yaml
   ```

2. **Lancez la capture** :
   ```bash
   kubectl kubeshark tap
   ```

3. **Observez le trafic** dans l'interface web qui s'ouvre automatiquement

### Vérifications

- [ ] Je peux observer le trafic HTTP entre mes pods
- [ ] Je comprends les communications dans mon cluster

## Objectifs pédagogiques

### Savoir

- [ ] Je sais ce qu’est un log, une métriques, un code d’erreur
- [ ] Je sais lire un code d’erreur
- [ ] J’ai sais citer des technos qui composent une stack de monitoring
- [ ] Je sais quelles métriques sont les plus intéressantes à regarder
- [ ] Je sais proposer une remédiation à mes erreurs
- [ ] Je connais le template d’un post-mortem

### Savoir-faire

- [ ] Je sais afficher les logs d’une application
- [ ] Je sais afficher et naviguer les logs collectés
- [ ] Je sais exposer des métriques d’une application
- [ ] Je sais déployer une stack de monitoring
- [ ] Je sais collecter les logs d’une application (dans k8s)
- [ ] Je sais debugger une application
- [ ] Je sais faire un post-mortem

## Conseils pour aller plus loin

### Ressources d'apprentissage
- **Documentation officielle** : <https://kubernetes.io/docs/>
- **Kubernetes Learning Path** : <https://github.com/kelseyhightower/kubernetes-the-hard-way>
- **Helm Best Practices** : <https://helm.sh/docs/chart_best_practices/>

### Prochaines étapes
1. **Pratiquez sur un vrai cluster** (EKS, GKE, AKS)
3. **Apprenez Istio** pour la gestion du service mesh
5. **Étudiez les opérateurs Kubernetes** pour automatiser la gestion d'applications

### Bonnes pratiques à retenir
- Utilisez toujours des resource requests et limits
- Implémentez des probes pour toutes vos applications
- Versionnez vos images de conteneurs (évitez `latest`)
- Utilisez des namespaces pour isoler vos environnements


helm install actions-runner-controller actions-runner-controller/actions-runner-controller --namespace actions --create-namespace --version 0.22.0 -f runner-controller.yaml

helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.13.0 --set installCRDs=true


##### Add repository 
```shell helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller ``` 
##### Install Helm chart ```shell helm upgrade --install --namespace actions-runner-system --create-namespace --set=authSecret.create=true --set=authSecret.github_token="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" --wait actions-runner-controller actions-runner-controller/actions-runner-controller ``` 

*note:- Replace REPLACE_YOUR_TOKEN_HERE with your PAT that was generated previously.