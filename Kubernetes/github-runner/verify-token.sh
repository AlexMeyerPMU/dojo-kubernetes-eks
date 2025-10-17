#!/bin/bash

# GitHub Token Verification Script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitHub Token Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get token from secret or prompt
if kubectl get secret controller-manager -n actions-runner-system &>/dev/null; then
    echo "Reading token from Kubernetes secret..."
    GITHUB_TOKEN=$(kubectl get secret controller-manager -n actions-runner-system -o jsonpath='{.data.github_token}' | base64 -d)
else
    echo -e "${YELLOW}Enter your GitHub PAT:${NC}"
    read -s GITHUB_TOKEN
    echo ""
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: No token provided${NC}"
    exit 1
fi

echo -e "${YELLOW}Testing GitHub Token...${NC}"
echo ""

# Test 1: Basic authentication
echo "1. Testing basic authentication..."
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user)
HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AUTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    USERNAME=$(echo "$RESPONSE_BODY" | grep -o '"login":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Token is valid${NC}"
    echo "  Authenticated as: $USERNAME"
else
    echo -e "${RED}✗ Token authentication failed (HTTP $HTTP_CODE)${NC}"
    echo "  Token may be invalid or expired"
    exit 1
fi
echo ""

# Test 2: Check token scopes
echo "2. Checking token permissions..."
SCOPES=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -i "x-oauth-scopes:" | cut -d' ' -f2- | tr -d '\r')

echo "  Token scopes: $SCOPES"

HAS_REPO=false
if echo "$SCOPES" | grep -q "repo"; then
    echo -e "${GREEN}  ✓ Has 'repo' scope${NC}"
    HAS_REPO=true
else
    echo -e "${RED}  ✗ Missing 'repo' scope (REQUIRED)${NC}"
fi

if echo "$SCOPES" | grep -q "workflow"; then
    echo -e "${GREEN}  ✓ Has 'workflow' scope${NC}"
else
    echo -e "${YELLOW}  ! Missing 'workflow' scope (recommended)${NC}"
fi
echo ""

# Test 3: Check repository access
echo "3. Testing repository access..."
REPO="AlexMeyerPMU/dojo-kubernetes-eks"
echo "  Testing: $REPO"

REPO_RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$REPO")
REPO_HTTP_CODE=$(echo "$REPO_RESPONSE" | tail -n1)

if [ "$REPO_HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Can access $REPO${NC}"
    REPO_BODY=$(echo "$REPO_RESPONSE" | sed '$d')
    FULL_NAME=$(echo "$REPO_BODY" | grep -o '"full_name":"[^"]*' | cut -d'"' -f4)
    PERMISSIONS=$(echo "$REPO_BODY" | grep -o '"permissions":{[^}]*}')
    echo "  Full name: $FULL_NAME"
    if echo "$PERMISSIONS" | grep -q '"admin":true\|"push":true'; then
        echo -e "${GREEN}  ✓ Has write access to repository${NC}"
    else
        echo -e "${RED}  ✗ No write access - token needs push/admin permission${NC}"
    fi
else
    echo -e "${RED}  ✗ Cannot access $REPO (HTTP $REPO_HTTP_CODE)${NC}"
    if [ "$REPO_HTTP_CODE" = "404" ]; then
        echo "  Repository not found or no access"
        echo "  Trying alternate repository: padok-team/dojo-kubernetes-eks"
        
        REPO2="padok-team/dojo-kubernetes-eks"
        REPO2_RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$REPO2")
        REPO2_HTTP_CODE=$(echo "$REPO2_RESPONSE" | tail -n1)
        
        if [ "$REPO2_HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}  ✓ Can access $REPO2${NC}"
            echo -e "${YELLOW}  → Update runnerdeployment.yaml to use: $REPO2${NC}"
        else
            echo -e "${RED}  ✗ Cannot access $REPO2 either${NC}"
        fi
    fi
fi
echo ""

# Test 4: Test runner registration endpoint
echo "4. Testing runner registration API..."
if [ "$HAS_REPO" = true ]; then
    REG_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/actions/runners/registration-token")
    REG_HTTP_CODE=$(echo "$REG_RESPONSE" | tail -n1)
    
    if [ "$REG_HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}  ✓ Can create runner registration tokens${NC}"
        echo -e "${GREEN}  ✓ Token has all required permissions!${NC}"
    else
        echo -e "${RED}  ✗ Cannot create registration tokens (HTTP $REG_HTTP_CODE)${NC}"
        REG_BODY=$(echo "$REG_RESPONSE" | sed '$d')
        echo "  Response: $REG_BODY"
        echo ""
        echo -e "${RED}  This is the exact error the controller is encountering!${NC}"
    fi
else
    echo -e "${YELLOW}  Skipped (missing repo scope)${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$HTTP_CODE" = "200" ] && [ "$HAS_REPO" = true ] && [ "$REPO_HTTP_CODE" = "200" ] && [ "$REG_HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Token is correctly configured!${NC}"
    echo ""
    echo "Your token should work. If runners still don't register:"
    echo "1. Verify the repository name in runnerdeployment.yaml"
    echo "2. Restart the controller: kubectl rollout restart deployment actions-runner-controller -n actions-runner-system"
else
    echo -e "${RED}✗ Token has issues that need to be fixed${NC}"
    echo ""
    echo "Required actions:"
    if [ "$HTTP_CODE" != "200" ]; then
        echo "  • Generate a new token (current one is invalid)"
    fi
    if [ "$HAS_REPO" != true ]; then
        echo "  • Token needs 'repo' scope (full control of private repos)"
    fi
    if [ "$REPO_HTTP_CODE" != "200" ]; then
        echo "  • Verify repository name in runnerdeployment.yaml"
        echo "  • Ensure token has access to the repository"
    fi
    if [ "$REG_HTTP_CODE" != "201" ] && [ "$HAS_REPO" = true ]; then
        echo "  • Token needs push/admin access to the repository"
    fi
    echo ""
    echo "To fix:"
    echo "1. Go to GitHub → Settings → Developer settings → Personal access tokens"
    echo "2. Generate new token with 'repo' scope"
    echo "3. Update the secret:"
    echo "   kubectl delete secret controller-manager -n actions-runner-system"
    echo "   kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=NEW_TOKEN"
    echo "4. Restart controller:"
    echo "   kubectl rollout restart deployment actions-runner-controller -n actions-runner-system"
fi
echo ""
