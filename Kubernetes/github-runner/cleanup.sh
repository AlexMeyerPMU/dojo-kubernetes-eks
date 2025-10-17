#!/bin/bash

# Cleanup script for GitHub Actions Runner Controller
# Use this to remove previous installations before reinstalling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}GitHub Actions Runner Cleanup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

echo -e "${YELLOW}This will remove ALL Actions Runner Controller installations${NC}"
echo -e "${YELLOW}from your cluster, including:${NC}"
echo "  - Runner deployments and pods"
echo "  - Controller deployments"
echo "  - CRDs and cluster roles"
echo "  - Namespaces: actions, actions-runner-system"
echo ""

read -p "Are you sure you want to proceed? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Step 1: Delete runner deployments from all namespaces
echo -e "${YELLOW}1. Deleting runner deployments...${NC}"
kubectl delete runnerdeployment --all --all-namespaces --ignore-not-found=true
echo -e "${GREEN}✓ Runner deployments deleted${NC}"
echo ""

# Step 2: Uninstall Helm releases from both namespaces
echo -e "${YELLOW}2. Uninstalling Helm releases...${NC}"

# Check and uninstall from 'actions' namespace
if helm list -n actions 2>/dev/null | grep -q actions-runner-controller; then
    echo "Uninstalling from 'actions' namespace..."
    helm uninstall actions-runner-controller -n actions
    echo -e "${GREEN}✓ Uninstalled from 'actions' namespace${NC}"
else
    echo "No Helm release found in 'actions' namespace"
fi

# Check and uninstall from 'actions-runner-system' namespace
if helm list -n actions-runner-system 2>/dev/null | grep -q actions-runner-controller; then
    echo "Uninstalling from 'actions-runner-system' namespace..."
    helm uninstall actions-runner-controller -n actions-runner-system
    echo -e "${GREEN}✓ Uninstalled from 'actions-runner-system' namespace${NC}"
else
    echo "No Helm release found in 'actions-runner-system' namespace"
fi
echo ""

# Step 3: Delete CRDs
echo -e "${YELLOW}3. Deleting Custom Resource Definitions...${NC}"
kubectl delete crd \
    horizontalrunnerautoscalers.actions.summerwind.dev \
    runnerdeployments.actions.summerwind.dev \
    runnerreplicasets.actions.summerwind.dev \
    runners.actions.summerwind.dev \
    runnersets.actions.summerwind.dev \
    --ignore-not-found=true
echo -e "${GREEN}✓ CRDs deleted${NC}"
echo ""

# Step 4: Delete ClusterRoles and ClusterRoleBindings
echo -e "${YELLOW}4. Deleting cluster-wide resources...${NC}"
kubectl delete clusterrole \
    actions-runner-controller-manager \
    actions-runner-controller-proxy-role \
    actions-runner-controller-metrics-reader \
    --ignore-not-found=true

kubectl delete clusterrolebinding \
    actions-runner-controller-manager \
    actions-runner-controller-proxy-rolebinding \
    --ignore-not-found=true
echo -e "${GREEN}✓ Cluster roles deleted${NC}"
echo ""

# Step 5: Delete MutatingWebhookConfigurations
echo -e "${YELLOW}5. Deleting webhook configurations...${NC}"
kubectl delete mutatingwebhookconfigurations \
    actions-runner-controller-mutating-webhook-configuration \
    --ignore-not-found=true
echo -e "${GREEN}✓ Webhooks deleted${NC}"
echo ""

# Step 6: Delete ValidatingWebhookConfigurations
echo -e "${YELLOW}6. Deleting validating webhook configurations...${NC}"
kubectl delete validatingwebhookconfigurations \
    actions-runner-controller-validating-webhook-configuration \
    --ignore-not-found=true
echo -e "${GREEN}✓ Validating webhooks deleted${NC}"
echo ""

# Step 7: Delete namespaces
echo -e "${YELLOW}7. Deleting namespaces...${NC}"

if kubectl get namespace actions &>/dev/null; then
    echo "Deleting 'actions' namespace..."
    kubectl delete namespace actions --timeout=60s
    echo -e "${GREEN}✓ 'actions' namespace deleted${NC}"
fi

if kubectl get namespace actions-runner-system &>/dev/null; then
    echo "Deleting 'actions-runner-system' namespace..."
    kubectl delete namespace actions-runner-system --timeout=60s
    echo -e "${GREEN}✓ 'actions-runner-system' namespace deleted${NC}"
fi
echo ""

# Step 8: Wait for namespaces to be fully deleted
echo -e "${YELLOW}8. Waiting for complete cleanup...${NC}"
echo "This may take a minute..."

# Wait for 'actions' namespace
count=0
while kubectl get namespace actions &>/dev/null; do
    sleep 2
    count=$((count + 1))
    if [ $count -gt 30 ]; then
        echo -e "${RED}Warning: 'actions' namespace deletion taking longer than expected${NC}"
        break
    fi
done

# Wait for 'actions-runner-system' namespace
count=0
while kubectl get namespace actions-runner-system &>/dev/null; do
    sleep 2
    count=$((count + 1))
    if [ $count -gt 30 ]; then
        echo -e "${RED}Warning: 'actions-runner-system' namespace deletion taking longer than expected${NC}"
        break
    fi
done

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 9: Verification
echo -e "${YELLOW}9. Verifying cleanup...${NC}"
echo ""

echo "Checking for remaining resources:"
echo "  Namespaces:"
kubectl get namespace | grep -E "actions" || echo "    None found ✓"
echo ""

echo "  Runner CRDs:"
kubectl get crd | grep actions.summerwind.dev || echo "    None found ✓"
echo ""

echo "  ClusterRoles:"
kubectl get clusterrole | grep actions-runner-controller || echo "    None found ✓"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "You can now run a fresh installation:"
echo -e "${YELLOW}  ./install.sh${NC}"
echo ""
