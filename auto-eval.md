# Auto évaluation Kubernetes

## Docker

- [x] Je connais les best practices sur la conteneurisation appli
- [x] Je sais conteneuriser une application
- [x] Je sais conteneuriser en multi stage
- [x] Je sais conteneuriser pour différentes infrastructures (X64/ARM64)
- [x] Je sais déployer une stack docker compose
- [ ] Je sais afficher le SBOM d’une image
- [x] Je sais afficher l’historique d’une image
- [ ] Je sais mettre en place du hot reloading

## Kubernetes

- [X] Je sais ce qu’est un pod
- [X] Je sais ce qu’est un déploiement vs statefulset vs daemonset
- [ ] Je comprends les indication min/max Surge
- [x] Je sais ce qu’est une configmap
- [x] Je sais ce qu’est une application stateless
- [ ] Je comprends le fonctionnement d’external-secret
- [ ] Je comprends le fonctionnement du control plane
- [ ] Je comprends le fonctionnement du scheduler
- [x] Je comprends le templating helm
- [ ] Je comprends le patching kustomize
- [ ] Je connais le toolkit minimal d’admin k8s
- [ ] Je sais rolling update un déploiement / sts / daemonset
- [ ] Je sais importer des secrets depuis un référentiel externe
- [x] Je sais utiliser kubectl explain
- [ ] Je sais update la valeur d’un secret
- [ ] Je sais update une configmap
- [x] Je sais déployer une application avec Helm

## Observabilité

- [ ] Je sais quelles métriques sont importantes à observer
- [x] Je sais consulter les métriques machines de mon ~~EKS~~ cluster k8s
- [x] Je sais consulter les logs de mon ~~EKS~~ cluster k8s
- [x] Je sais consulter les events kube
- [x] Je sais consulter les consommations des pods

## Lancement en production

- [x] Je sais comment fine tuner un déploiement pour une application (req/lim)
- [x] Je sais load stress une application
- [x] Je sais déployer en mode GitOps
- [x] Je sais faire scale mon application
- [ ] Je sais mettre en place des PDB
- [ ] Je sais isoler mes namespaces niveau réseau
- [ ] Je sais mettre en place des spread constraints
- [ ] Je sais mettre en place des affinity

## (Optionnel) EKS

- [ ] Je comprends l’architecture d’EKS
- [ ] Je sais déployer une ECR
- [ ] Je sais déployer un LB depuis le cluster EKS
- [ ] Je sais déployer un EKS
- [ ] Je sais déployer un bastion SSM
- [ ] Je sais déployer un Cloudfront branché à EKS
- [ ] Je sais configurer cloudtrail pour EKS

## (Optionnel) Manager un cluster EKS

- [ ] Je comprends le fonctionnement de Karpenter
- [ ] Je comprends comment initialiser des droits IAM sur un cluster EKS
- [ ] Je sais mettre en place des droits RBAC limités
- [ ] Je sais sizer mes nodepools
- [ ] Je sais upgrade un cluster EKS
- [ ] Je sais identifier les incompatibilités des resource APIs avec la nouvelle version de mon cluster