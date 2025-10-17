# Troubleshooting Guide - GitHub Actions Runner

This guide covers common issues and their solutions when setting up GitHub Actions runners in Kubernetes.

## Error: ClusterRole exists from previous installation

**Symptoms:**
```
ClusterRole "actions-runner-controller-manager" in namespace "" exists and cannot be imported 
into the current release: invalid ownership metadata; annotation validation error: 
key "meta.helm.sh/release-namespace" must equal "actions-runner-system": 
current value is "actions"
```

**Cause:** You have a previous installation of Actions Runner Controller in a different namespace (likely "actions") that's conflicting with the new installation.

**Solution:**

### Quick Fix - Use the Cleanup Script
```bash
cd Kubernetes/github-runner

# Run the cleanup script
./cleanup.sh

# Type 'yes' when prompted

# After cleanup completes, run the installer
./install.sh
```

The cleanup script will:
- Remove all runner deployments
- Uninstall Helm releases from both namespaces
- Delete CRDs and cluster-wide resources
- Delete conflicting namespaces
- Verify complete cleanup

### Manual Cleanup (Alternative)
If you prefer to clean up manually:

```bash
# 1. Delete runner deployments
kubectl delete runnerdeployment --all --all-namespaces

# 2. Uninstall from old namespace
helm uninstall actions-runner-controller -n actions

# 3. Delete the old namespace
kubectl delete namespace actions

# 4. Delete cluster-wide resources
kubectl delete clusterrole actions-runner-controller-manager
kubectl delete clusterrolebinding actions-runner-controller-manager

# 5. Delete CRDs
kubectl delete crd runnerdeployments.actions.summerwind.dev
kubectl delete crd runners.actions.summerwind.dev
kubectl delete crd horizontalrunnerautoscalers.actions.summerwind.dev

# 6. Wait for complete deletion, then reinstall
./install.sh
```

---

## Error: "no endpoints available for service actions-runner-controller-webhook"

**Symptoms:**
```
Error from server (InternalError): error when creating "runnerdeployment.yaml": 
Internal error occurred: failed calling webhook "mutate.runnerdeployment.actions.summerwind.dev": 
failed to call webhook: Post "https://actions-runner-controller-webhook.actions.svc:443/...": 
no endpoints available for service "actions-runner-controller-webhook"
```

**Cause:** The webhook service hasn't finished starting up when you try to deploy runners.

**Solution:**

### Quick Fix
Wait for the webhook to be ready, then retry:

```bash
# Wait for webhook endpoints to be available
kubectl wait --for=jsonpath='{.subsets[0].addresses[0].ip}' \
  endpoints/actions-runner-controller-webhook \
  -n actions-runner-system \
  --timeout=120s

# Now deploy runners
kubectl apply -f runnerdeployment.yaml
```

### Alternative: Manual Check
```bash
# Check if webhook service has endpoints
kubectl get endpoints actions-runner-controller-webhook -n actions-runner-system

# You should see IP addresses listed. If empty, wait and check again
# Example of ready endpoint:
# NAME                                ENDPOINTS         AGE
# actions-runner-controller-webhook   10.42.0.15:9443   2m

# Once endpoints appear, deploy runners
kubectl apply -f runnerdeployment.yaml
```

### If Problem Persists
1. Check controller pod status:
   ```bash
   kubectl get pods -n actions-runner-system
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
   ```

2. Restart the controller if needed:
   ```bash
   kubectl rollout restart deployment actions-runner-controller -n actions-runner-system
   kubectl wait --for=condition=Available deployment/actions-runner-controller -n actions-runner-system
   ```

3. Wait 30 seconds then try deploying runners again

---

## Error: Helm values "cannot overwrite table with non table"

**Symptoms:**
```
coalesce.go:298: warning: cannot overwrite table with non table for 
actions-runner-controller.metrics.serviceMonitor (map[enable:false ...])
```

**Cause:** Incorrect structure in Helm values file for the metrics configuration.

**Solution:**
The `runner-controller-values.yaml` file has been updated with the correct structure:

```yaml
metrics:
  serviceMonitor:
    enabled: false  # Must be nested under serviceMonitor
```

If you see this error, make sure your values file matches the provided template.

---

## Runners Not Appearing in GitHub

**Symptoms:**
- Helm installation completes successfully
- No runners visible in GitHub Settings → Actions → Runners

**Diagnosis Steps:**

1. **Check runner pods:**
   ```bash
   kubectl get pods -l app.kubernetes.io/name=actions-runner
   ```
   
   Expected: You should see runner pods in Running state

2. **Check runner deployment:**
   ```bash
   kubectl get runnerdeployments
   kubectl describe runnerdeployment github-runner
   ```

3. **Check runner logs:**
   ```bash
   kubectl logs -l app.kubernetes.io/name=actions-runner --tail=100
   ```

4. **Check controller logs:**
   ```bash
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller --tail=100
   ```

**Common Causes & Solutions:**

### Invalid GitHub Token
**Symptoms in logs:** "Bad credentials" or "401 Unauthorized"

**Solution:**
```bash
# Verify token has correct permissions (repo scope)
# Delete old secret and create new one
kubectl delete secret controller-manager -n actions-runner-system
kubectl create secret generic controller-manager \
  -n actions-runner-system \
  --from-literal=github_token=YOUR_NEW_GITHUB_PAT
  
# Restart controller to pick up new secret
kubectl rollout restart deployment actions-runner-controller -n actions-runner-system
```

### Wrong Repository Name
**Check your runnerdeployment.yaml:**
```yaml
spec:
  template:
    spec:
      repository: owner/repo-name  # Must match exactly
```

**Solution:**
```bash
# Edit the deployment
kubectl edit runnerdeployment github-runner

# Or update file and reapply
kubectl apply -f runnerdeployment.yaml
```

### Rate Limited by GitHub
**Symptoms in logs:** "API rate limit exceeded"

**Solution:** Wait a few minutes for rate limit to reset, or use a different PAT.

---

## cert-manager Issues

**Symptoms:**
- Controller pod in CrashLoopBackOff
- Certificate errors in logs

**Solution:**

1. **Verify cert-manager is running:**
   ```bash
   kubectl get pods -n cert-manager
   ```
   All pods should be Running.

2. **Check cert-manager logs:**
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager
   ```

3. **Reinstall cert-manager if needed:**
   ```bash
   kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
   # Wait a minute
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
   kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
   ```

---

## Runner Pod Stuck in Pending

**Symptoms:**
```bash
kubectl get pods
# NAME                           READY   STATUS    RESTARTS   AGE
# github-runner-xxxxx-xxxxx      0/2     Pending   0          5m
```

**Diagnosis:**
```bash
kubectl describe pod <runner-pod-name>
```

**Common Causes:**

### Insufficient Resources
**Solution:** Check node resources and reduce runner resource requests:
```yaml
# In runnerdeployment.yaml
resources:
  requests:
    cpu: "250m"    # Reduced from 500m
    memory: "512Mi" # Reduced from 1Gi
```

### No Available Nodes
**Solution:** 
```bash
# Check nodes
kubectl get nodes

# Check node resources
kubectl top nodes

# Add more nodes or free up resources
```

---

## Docker-in-Docker Not Working

**Symptoms:**
- Workflows fail with "docker: command not found"
- Cannot build containers in runners

**Solution:**

Ensure `dockerdWithinRunnerContainer: true` in your runnerdeployment.yaml:

```yaml
spec:
  template:
    spec:
      dockerdWithinRunnerContainer: true  # Must be true for Docker support
```

Then reapply:
```bash
kubectl apply -f runnerdeployment.yaml
```

---

## Namespace Already Exists Error

**Symptoms:**
```
Error: namespace "actions-runner-system" already exists
```

**Solution:**
This is usually safe to ignore. The namespace exists from a previous installation.

If you want to start fresh:
```bash
# WARNING: This deletes everything
kubectl delete namespace actions-runner-system --grace-period=0 --force

# Wait for complete deletion
kubectl get namespace actions-runner-system
# Should show: Error from server (NotFound)

# Now reinstall
./install.sh
```

---

## Runner Logs Show "Offline" Status

**Symptoms:**
- Runner appears in GitHub but shows as "Offline"
- Runner pod is Running

**Diagnosis:**
```bash
kubectl logs -l app.kubernetes.io/name=actions-runner -f
```

**Common Causes:**

1. **Network connectivity issues** - Check if pod can reach GitHub
2. **Token expired** - Regenerate and update secret
3. **Runner name conflict** - Delete and recreate runner

**Solution:**
```bash
# Delete runner deployment
kubectl delete runnerdeployment github-runner

# Wait a moment
sleep 10

# Redeploy
kubectl apply -f runnerdeployment.yaml
```

---

## Complete Reset / Clean Installation

If all else fails, here's how to do a complete clean installation:

```bash
# 1. Delete runners
kubectl delete runnerdeployment --all

# 2. Uninstall controller
helm uninstall actions-runner-controller -n actions-runner-system

# 3. Delete namespace (this removes everything)
kubectl delete namespace actions-runner-system

# 4. Wait for complete deletion
while kubectl get namespace actions-runner-system &> /dev/null; do
    echo "Waiting for namespace deletion..."
    sleep 5
done

# 5. Optional: Reinstall cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
sleep 30
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# 6. Run fresh installation
cd Kubernetes/github-runner
./install.sh
```

---

## Getting Help

If you're still experiencing issues:

1. **Collect diagnostic information:**
   ```bash
   # Save all relevant logs
   kubectl get all -n actions-runner-system > diagnostics.txt
   kubectl describe pods -n actions-runner-system >> diagnostics.txt
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller --tail=200 >> diagnostics.txt
   kubectl get runnerdeployments -o yaml >> diagnostics.txt
   kubectl get runners -o yaml >> diagnostics.txt
   ```

2. **Check versions:**
   ```bash
   kubectl version --short
   helm version --short
   ```

3. **Useful resources:**
   - [Actions Runner Controller GitHub](https://github.com/actions/actions-runner-controller/issues)
   - [GitHub Actions Documentation](https://docs.github.com/en/actions)
   - [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
