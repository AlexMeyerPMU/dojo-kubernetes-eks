# GitHub Actions Self-Hosted Runner Setup for Kubernetes

This guide will help you deploy GitHub Actions self-hosted runners in your Rancher Kubernetes cluster using the Actions Runner Controller (ARC).

## Prerequisites

- Kubernetes cluster (Rancher Desktop or any K8s cluster)
- kubectl configured to access your cluster
- Helm 3 installed
- GitHub Personal Access Token (PAT) with appropriate permissions

## Step 1: Install cert-manager (Required)

The Actions Runner Controller requires cert-manager for TLS certificate management.

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

## Step 2: Create GitHub PAT Secret

Create a Kubernetes secret with your GitHub Personal Access Token.

**PAT Permissions Required:**
- For repository runners: `repo` (Full control of private repositories)
- For organization runners: `admin:org` (Full control of orgs and teams, read and write org projects)

```bash
# Replace YOUR_GITHUB_PAT with your actual token
kubectl create secret generic controller-manager \
  -n actions-runner-system \
  --from-literal=github_token=YOUR_GITHUB_PAT \
  --dry-run=client -o yaml | kubectl apply -f -
```

Or use the provided secret file:
```bash
kubectl apply -f github-runner/github-secret.yaml
```

## Step 3: Install Actions Runner Controller

Using Helm:

```bash
# Add the ARC Helm repository
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Create namespace
kubectl create namespace actions-runner-system

# Install the controller
helm install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --namespace actions-runner-system \
  --values github-runner/runner-controller-values.yaml \
  --wait
```

## Step 4: Deploy Runner for Your Repository

Update the `runnerdeployment.yaml` file with your GitHub repository details, then apply:

```bash
kubectl apply -f github-runner/runnerdeployment.yaml
```

## Step 5: Verify Installation

Check that everything is running:

```bash
# Check the controller
kubectl get pods -n actions-runner-system

# Check your runners
kubectl get runners
kubectl get runnerdeployments

# Check runner logs
kubectl logs -l app.kubernetes.io/name=actions-runner -f
```

## Configuration Options

### Runner Deployment Spec

The runner deployment supports various configurations:

```yaml
spec:
  replicas: 2  # Number of runner pods
  template:
    spec:
      repository: owner/repo-name  # For repo-level runners
      # OR
      organization: your-org-name  # For org-level runners
      
      # Optional configurations
      labels:
        - self-hosted
        - kubernetes
        - custom-label
      
      # Resource limits
      resources:
        limits:
          cpu: "2"
          memory: "4Gi"
        requests:
          cpu: "1"
          memory: "2Gi"
      
      # Docker-in-Docker for container builds
      dockerdWithinRunnerContainer: true
```

### Scaling Options

#### Manual Scaling
```bash
kubectl scale runnerdeployment guestbook-runnerdeploy --replicas=3
```

#### Auto-scaling with HRA (Horizontal Runner Autoscaler)
```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: runner-autoscaler
spec:
  scaleTargetRef:
    name: guestbook-runnerdeploy
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
    repositoryNames:
    - owner/repo-name
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check controller logs:
```bash
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
```

2. Check runner pod logs:
```bash
kubectl logs -l app.kubernetes.io/name=actions-runner
```

3. Verify secret:
```bash
kubectl get secret controller-manager -n actions-runner-system
```

### Common Issues

**Issue: "Failed to register runner"**
- Verify your PAT has correct permissions
- Ensure the repository/organization name is correct
- Check if the PAT has expired

**Issue: "cert-manager not ready"**
- Wait longer for cert-manager to initialize
- Check cert-manager pods: `kubectl get pods -n cert-manager`

**Issue: "Runner pod stuck in pending"**
- Check resource availability: `kubectl describe pod <runner-pod>`
- Verify storage provisioner if using PVCs

## Cleanup

To remove everything:

```bash
# Delete runner deployment
kubectl delete runnerdeployment guestbook-runnerdeploy

# Uninstall controller
helm uninstall actions-runner-controller -n actions-runner-system

# Delete namespace
kubectl delete namespace actions-runner-system

# Remove cert-manager (optional, if not used by other apps)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

## Using Your Self-Hosted Runners

In your GitHub Actions workflows, specify `runs-on: self-hosted`:

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: self-hosted  # Uses your Kubernetes runners
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          echo "Running on self-hosted Kubernetes runner!"
          # Your build/test commands here
```

## Additional Resources

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [cert-manager Documentation](https://cert-manager.io/docs/)
