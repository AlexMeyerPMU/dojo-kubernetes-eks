# Quick Start Guide - GitHub Actions Runner

Follow these simple steps to get your self-hosted GitHub Actions runners running in Kubernetes.

## Prerequisites

✅ Kubernetes cluster (Rancher Desktop) running  
✅ `kubectl` configured and connected to your cluster  
✅ `helm` installed (v3+)  
✅ GitHub Personal Access Token ready

## Getting Your GitHub PAT

1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name like "Kubernetes Runner"
4. Select these scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
   - If using organization runners, also add: `admin:org`
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

## Installation (3 Simple Steps)

### If You Have a Previous Installation

If you get an error about existing ClusterRoles or conflicts, clean up first:

```bash
cd Kubernetes/github-runner

# Run cleanup (removes any previous installations)
./cleanup.sh

# Type 'yes' when prompted
```

### Option A: Using the Installation Script (Easiest)

```bash
cd Kubernetes/github-runner

# Run the installer
./install.sh

# When prompted, paste your GitHub PAT
```

The script will automatically:
- Install cert-manager
- Create namespace
- Install Actions Runner Controller
- Deploy your runners

### Option B: Manual Installation

```bash
cd Kubernetes/github-runner

# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager

# 2. Create namespace and secret
kubectl create namespace actions-runner-system
kubectl create secret generic controller-manager \
  -n actions-runner-system \
  --from-literal=github_token=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

# 3. Install controller with Helm
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update
helm install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --namespace actions \
  --values runner-controller-values.yaml \
  --wait

# 4. Deploy runners
kubectl apply -f runnerdeployment.yaml
```

## Verification

Check that everything is running:

```bash
# Check controller
kubectl get pods -n actions-runner-system

# Check runners
kubectl get runners
kubectl get runnerdeployments

# View runner logs
kubectl logs -l app.kubernetes.io/name=actions-runner -f
```

## See Your Runners in GitHub

1. Go to your repository on GitHub
2. Click **Settings** → **Actions** → **Runners**
3. You should see your runner(s) listed with status "Idle" or "Active"

## Using Your Runners in Workflows

Create a workflow file in your repo (`.github/workflows/test-runner.yaml`):

```yaml
name: Test Self-Hosted Runner
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, kubernetes]
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Test runner
        run: |
          echo "Running on self-hosted Kubernetes runner!"
          echo "Node: $(uname -n)"
          echo "OS: $(uname -s)"
          
      - name: Check Docker
        run: docker --version
```

Push this workflow and watch it run on your Kubernetes runner!

## Common Tasks

### Scale Runners

```bash
# Scale up to 3 runners
kubectl scale runnerdeployment github-runner --replicas=3

# Scale down to 1 runner
kubectl scale runnerdeployment github-runner --replicas=1
```

### View Logs

```bash
# Controller logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -f

# Runner logs
kubectl logs -l app.kubernetes.io/name=actions-runner -f
```

### Update Configuration

```bash
# Edit runner deployment
kubectl edit runnerdeployment github-runner

# Or modify runnerdeployment.yaml and reapply
kubectl apply -f runnerdeployment.yaml
```

### Check Runner Status

```bash
# Get all runners
kubectl get runners

# Describe a specific runner
kubectl describe runner <runner-name>
```

## Troubleshooting

### Runner not showing up in GitHub?

1. Check controller logs:
   ```bash
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
   ```

2. Verify your secret has the correct token:
   ```bash
   kubectl get secret controller-manager -n actions-runner-system -o jsonpath='{.data.github_token}' | base64 -d
   ```

3. Check runner pod status:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=actions-runner
   kubectl describe pod <runner-pod-name>
   ```

### Workflow not using my runner?

- Ensure your workflow uses `runs-on: [self-hosted, kubernetes]`
- Check that at least one runner is "Idle" in GitHub Settings → Actions → Runners
- Verify the repository name in `runnerdeployment.yaml` matches your repo

### Pod stuck in pending?

```bash
# Check pod events
kubectl describe pod <runner-pod-name>

# Check if resources are available
kubectl top nodes
```

## Next Steps

- ✅ Add more runners by increasing replicas
- ✅ Set up auto-scaling with HorizontalRunnerAutoscaler
- ✅ Customize runner labels for different job types
- ✅ Configure resource limits for your workloads

## Cleanup

To remove everything:

```bash
# Delete runners
kubectl delete runnerdeployment github-runner

# Uninstall controller
helm uninstall actions-runner-controller -n actions-runner-system

# Delete namespace
kubectl delete namespace actions-runner-system

# Remove cert-manager (optional)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```

## Need Help?

- Check the detailed [README.md](README.md)
- Visit [Actions Runner Controller docs](https://github.com/actions/actions-runner-controller)
- Check [GitHub Actions documentation](https://docs.github.com/en/actions)
