#!/bin/bash

# Runner Diagnostics Script
# Helps identify why runners are offline

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitHub Runner Diagnostics${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check 1: Controller status
echo -e "${YELLOW}1. Checking controller status...${NC}"
CONTROLLER_STATUS=$(kubectl get deployment actions-runner-controller -n actions-runner-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)

if [ "$CONTROLLER_STATUS" = "True" ]; then
    echo -e "${GREEN}✓ Controller is running${NC}"
    kubectl get pods -n actions-runner-system
else
    echo -e "${RED}✗ Controller is not available${NC}"
    echo "Run: kubectl get pods -n actions-runner-system"
fi
echo ""

# Check 2: Runner deployments
echo -e "${YELLOW}2. Checking runner deployments...${NC}"
RUNNER_DEPLOYMENTS=$(kubectl get runnerdeployments 2>/dev/null)
if [ -z "$RUNNER_DEPLOYMENTS" ]; then
    echo -e "${RED}✗ No runner deployments found${NC}"
    echo "Create one with: kubectl apply -f runnerdeployment.yaml"
else
    echo "$RUNNER_DEPLOYMENTS"
fi
echo ""

# Check 3: Runner pods
echo -e "${YELLOW}3. Checking runner pods...${NC}"
RUNNER_PODS=$(kubectl get pods -l app.kubernetes.io/name=actions-runner 2>/dev/null)
if [ -z "$RUNNER_PODS" ]; then
    echo -e "${RED}✗ No runner pods found${NC}"
else
    echo "$RUNNER_PODS"
    echo ""
    
    # Check pod status
    PENDING=$(kubectl get pods -l app.kubernetes.io/name=actions-runner -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' 2>/dev/null)
    FAILED=$(kubectl get pods -l app.kubernetes.io/name=actions-runner -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null)
    RUNNING=$(kubectl get pods -l app.kubernetes.io/name=actions-runner -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null)
    
    if [ ! -z "$PENDING" ]; then
        echo -e "${YELLOW}⚠ Pods stuck in Pending:${NC}"
        echo "$PENDING"
        echo ""
        echo "Check with: kubectl describe pod $PENDING"
    fi
    
    if [ ! -z "$FAILED" ]; then
        echo -e "${RED}✗ Failed pods:${NC}"
        echo "$FAILED"
        echo ""
        echo "Check logs: kubectl logs $FAILED"
    fi
    
    if [ ! -z "$RUNNING" ]; then
        echo -e "${GREEN}✓ Running pods:${NC}"
        echo "$RUNNING"
    fi
fi
echo ""

# Check 4: Runner objects
echo -e "${YELLOW}4. Checking runner CRDs...${NC}"
RUNNERS=$(kubectl get runners 2>/dev/null)
if [ -z "$RUNNERS" ]; then
    echo -e "${RED}✗ No runner resources found${NC}"
else
    echo "$RUNNERS"
fi
echo ""

# Check 5: Recent logs
echo -e "${YELLOW}5. Checking recent runner logs...${NC}"
RUNNER_POD=$(kubectl get pods -l app.kubernetes.io/name=actions-runner -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$RUNNER_POD" ]; then
    echo "Latest logs from $RUNNER_POD:"
    echo "---"
    kubectl logs $RUNNER_POD --tail=20 2>/dev/null || echo "No logs available"
    echo "---"
else
    echo "No runner pods to check logs from"
fi
echo ""

# Check 6: Controller logs
echo -e "${YELLOW}6. Checking controller logs for errors...${NC}"
CONTROLLER_POD=$(kubectl get pods -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ ! -z "$CONTROLLER_POD" ]; then
    echo "Recent controller logs:"
    echo "---"
    kubectl logs -n actions-runner-system $CONTROLLER_POD --tail=20 2>/dev/null | grep -i "error\|fail\|token" || echo "No obvious errors"
    echo "---"
fi
echo ""

# Check 7: Secret
echo -e "${YELLOW}7. Checking GitHub token secret...${NC}"
if kubectl get secret controller-manager -n actions-runner-system &>/dev/null; then
    echo -e "${GREEN}✓ Secret exists${NC}"
    
    # Try to decode and check if it looks valid
    TOKEN=$(kubectl get secret controller-manager -n actions-runner-system -o jsonpath='{.data.github_token}' | base64 -d 2>/dev/null)
    if [ ${#TOKEN} -gt 30 ]; then
        echo -e "${GREEN}✓ Token appears valid (length: ${#TOKEN})${NC}"
    else
        echo -e "${RED}✗ Token may be invalid (length: ${#TOKEN})${NC}"
    fi
else
    echo -e "${RED}✗ Secret not found${NC}"
    echo "Create with: kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=YOUR_TOKEN"
fi
echo ""

# Summary and recommendations
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary & Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -z "$RUNNING" ]; then
    echo -e "${RED}❌ No runners are currently running${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo ""
    echo "1. Check if runner pods are stuck:"
    echo "   kubectl get pods -l app.kubernetes.io/name=actions-runner"
    echo ""
    echo "2. If pods are Pending, check events:"
    echo "   kubectl describe pod \$(kubectl get pods -l app.kubernetes.io/name=actions-runner -o name | head -1)"
    echo ""
    echo "3. If pods are CrashLooping, check logs:"
    echo "   kubectl logs -l app.kubernetes.io/name=actions-runner"
    echo ""
    echo "4. Check controller logs for registration errors:"
    echo "   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller --tail=50"
    echo ""
    echo "5. Verify GitHub token is correct:"
    echo "   ./verify-token.sh"
    echo ""
    echo "6. Try recreating runners:"
    echo "   kubectl delete runnerdeployment github-runner"
    echo "   kubectl apply -f runnerdeployment.yaml"
else
    echo -e "${GREEN}✓ Runners are running!${NC}"
    echo ""
    echo "If they still show as offline in GitHub:"
    echo ""
    echo "1. Wait 1-2 minutes for GitHub to update status"
    echo ""
    echo "2. Check runner logs for connection issues:"
    echo "   kubectl logs $RUNNER_POD"
    echo ""
    echo "3. Verify the repository name matches:"
    echo "   Repository in GitHub: AlexMeyerPMU/dojo-kubernetes-eks"
    echo "   Repository in config: \$(kubectl get runnerdeployment github-runner -o jsonpath='{.spec.template.spec.repository}')"
    echo ""
    echo "4. Check if runners need to be restarted:"
    echo "   kubectl delete pod -l app.kubernetes.io/name=actions-runner"
fi
echo ""
