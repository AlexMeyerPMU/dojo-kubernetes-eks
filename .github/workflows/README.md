# GitHub Actions Workflows

This directory contains automated workflows for the dojo-kubernetes-eks project.

## Workflows

### 1. Docker Build and Push (`docker-build-push.yaml`)

Automatically builds the Go guestbook application and pushes it to Docker Hub.

**Trigger:**
- Push to `main`, `master`, or `develop` branches (when Docker/ files change)
- Manual trigger via GitHub Actions UI

**What it does:**
- Builds the Go application using `Docker/Dockerfile`
- Tags the image with branch name, commit SHA, and `latest` (for default branch)
- Pushes to Docker Hub
- Uses build cache for faster builds

**Image naming:**
- Repository: `<your-dockerhub-username>/guestbook-go`
- Tags:
  - `latest` (for main/master branch)
  - `<branch-name>` (e.g., `develop`)
  - `<branch>-<sha>` (e.g., `main-abc1234`)

## Setup Required

### Docker Hub Secrets

You need to add two secrets to your GitHub repository:

1. **Go to your repository on GitHub**
   - Navigate to: `Settings` → `Secrets and variables` → `Actions`

2. **Add these secrets:**

   #### `DOCKERHUB_USERNAME`
   - Your Docker Hub username
   - Example: `alexmeyer` or `your-dockerhub-username`

   #### `DOCKERHUB_TOKEN`
   - A Docker Hub access token (NOT your password!)
   - **How to create:**
     1. Log in to [Docker Hub](https://hub.docker.com)
     2. Go to `Account Settings` → `Security` → `Access Tokens`
     3. Click `New Access Token`
     4. Name: `GitHub Actions`
     5. Permissions: `Read, Write, Delete`
     6. Click `Generate`
     7. **Copy the token immediately** (you won't see it again)
     8. Paste it in GitHub as `DOCKERHUB_TOKEN`

### Quick Setup Commands

```bash
# Step 1: Create Docker Hub access token (do this in Docker Hub web UI)

# Step 2: Add secrets to GitHub (do this in GitHub web UI)
# Settings → Secrets and variables → Actions → New repository secret

# Name: DOCKERHUB_USERNAME
# Value: your-dockerhub-username

# Name: DOCKERHUB_TOKEN
# Value: dckr_pat_xxxxxxxxxxxxxxxxxxxxx
```

## Testing the Workflow

### Manual Trigger

1. Go to your repository on GitHub
2. Click `Actions` tab
3. Select `Build and Push Docker Image` workflow
4. Click `Run workflow`
5. Select branch and click `Run workflow`

### Automatic Trigger

Simply push changes to the `Docker/` directory:

```bash
# Make a change to the Go app
cd Docker
echo "// test" >> main.go

# Commit and push
git add main.go
git commit -m "test: trigger Docker build"
git push origin main
```

The workflow will automatically start!

## Viewing Build Results

1. Go to `Actions` tab in your repository
2. Click on the running workflow
3. View logs and build progress
4. After success, check Docker Hub for your new image

## Using the Built Image

After the workflow completes, you can pull and use the image:

```bash
# Pull the latest image
docker pull <your-username>/guestbook-go:latest

# Or pull a specific tag
docker pull <your-username>/guestbook-go:main-abc1234

# Run the container
docker run -p 3000:3000 <your-username>/guestbook-go:latest
```

## Update Kubernetes Deployment

To use the newly built image in your Kubernetes deployment:

```bash
# Update the image in your deployment
kubectl set image deployment/guestbook-deployment \
  guestbook=<your-username>/guestbook-go:latest

# Or update values.yaml in the Helm chart
# Edit: Kubernetes/guestbook/values.yaml
# Change:
#   image:
#     repository: <your-username>/guestbook-go
#     tag: "latest"
```

## Troubleshooting

### Workflow fails with "Error: Cannot perform an interactive login from a non TTY device"

**Solution:** Make sure you've added the Docker Hub secrets correctly.

### Workflow fails with "denied: requested access to the resource is denied"

**Possible causes:**
1. Docker Hub token doesn't have write permissions
2. Repository name doesn't match your Docker Hub username
3. Token has expired

**Solution:**
1. Generate a new Docker Hub token with Read, Write permissions
2. Update the `DOCKERHUB_TOKEN` secret
3. Re-run the workflow

### Build fails with Go errors

**Check:**
1. The Dockerfile is correct
2. Go dependencies are properly defined in `go.mod`
3. The build context is set correctly (`Docker/` directory)

### Self-hosted runner not picking up the job

**Solution:**
1. Check runners are active: Go to Settings → Actions → Runners
2. If using GitHub-hosted runners instead, change in workflow:
   ```yaml
   runs-on: ubuntu-latest  # Instead of [self-hosted, kubernetes]
   ```

## Advanced Configuration

### Build for Multiple Architectures

To build for both AMD64 and ARM64:

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    # ... rest of configuration
```

### Add Build Arguments

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    build-args: |
      GO_VERSION=1.21
      BUILD_DATE=${{ github.event.head_commit.timestamp }}
    # ... rest of configuration
```

### Scan for Vulnerabilities

Add after build step:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ secrets.DOCKERHUB_USERNAME }}/guestbook-go:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
```

## Resources

- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
