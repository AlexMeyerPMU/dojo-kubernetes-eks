#!/bin/bash

# GitHub Actions Runner Installation Script for Kubernetes
# This script installs the Actions Runner Controller and deploys GitHub runners

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitHub Actions Runner Setup for K8s${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Get GitHub PAT from user
if [ -z "$GITHUB_PAT" ]; then
    echo -e "${YELLOW}Please enter your GitHub Personal Access Token:${NC}"
    read -s GITHUB_PAT
    echo ""
fi

if [ -z "$GITHUB_PAT" ]; then
    echo -e "${RED}Error: GitHub PAT is required${NC}"
    exit 1
fi

# Step 1: Install cert-manager
echo -e "${YELLOW}Step 1: Installing cert-manager...${NC}"
if kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${GREEN}✓ cert-manager namespace already exists${NC}"
else
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager || true
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager || true
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager || true
    echo -e "${GREEN}✓ cert-manager installed${NC}"
fi
echo ""

# Step 2: Create namespace
echo -e "${YELLOW}Step 2: Creating actions-runner-system namespace...${NC}"
kubectl create namespace actions-runner-system --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Step 3: Create secret with GitHub PAT
echo -e "${YELLOW}Step 3: Creating GitHub PAT secret...${NC}"
kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=$GITHUB_PAT \
    --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Secret created${NC}"
echo ""

# Step 4: Add Helm repo and install controller
echo -e "${YELLOW}Step 4: Installing Actions Runner Controller...${NC}"
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

if helm list -n actions-runner-system | grep -q actions-runner-controller; then
    echo "Upgrading existing installation..."
    helm upgrade actions-runner-controller \
        actions-runner-controller/actions-runner-controller \
        --namespace actions-runner-system \
        --values runner-controller-values.yaml \
        --wait
else
    echo "Installing new instance..."
    helm install actions-runner-controller \
        actions-runner-controller/actions-runner-controller \
        --namespace actions-runner-system \
        --values runner-controller-values.yaml \
        --wait
fi
echo -e "${GREEN}✓ Controller installed${NC}"
echo ""

# Step 5: Wait for controller to be ready
echo -e "${YELLOW}Step 5: Waiting for controller to be ready...${NC}"
kubectl wait --for=condition=Available --timeout=300s deployment/actions-runner-controller -n actions-runner-system || true

# Wait for webhook service to have endpoints
echo "Waiting for webhook service to be ready..."
for i in {1..60}; do
    if kubectl get endpoints actions-runner-controller-webhook -n actions-runner-system &> /dev/null; then
        ENDPOINTS=$(kubectl get endpoints actions-runner-controller-webhook -n actions-runner-system -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ ! -z "$ENDPOINTS" ]; then
            echo -e "${GREEN}✓ Webhook service is ready${NC}"
            break
        fi
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}Warning: Webhook service not ready after 60 seconds${NC}"
        echo "You may need to wait a bit longer before deploying runners"
    fi
    sleep 2
done
echo ""

# Step 6: Deploy runners
echo -e "${YELLOW}Step 6: Deploying GitHub runners...${NC}"
echo "Waiting a few more seconds for webhook to stabilize..."
sleep 5
kubectl apply -f runnerdeployment.yaml
echo -e "${GREEN}✓ Runner deployment created${NC}"
echo ""

# Step 7: Verification
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Verifying installation...${NC}"
echo ""

echo "Controller status:"
kubectl get pods -n actions-runner-system
echo ""

echo "Waiting for runners to be created (this may take a minute)..."
sleep 10
echo ""

echo "Runner deployments:"
kubectl get runnerdeployments
echo ""

echo "Runner pods:"
kubectl get runners
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Instructions${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Check runner status in GitHub:"
echo "   Go to your repository → Settings → Actions → Runners"
echo ""
echo "2. Use self-hosted runners in your workflows:"
echo "   runs-on: [self-hosted, kubernetes]"
echo ""
echo "3. View runner logs:"
echo "   kubectl logs -l app.kubernetes.io/name=actions-runner -f"
echo ""
echo "4. Scale runners:"
echo "   kubectl scale runnerdeployment github-runner --replicas=3"
echo ""
echo "5. Check controller logs:"
echo "   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller"
echo ""
