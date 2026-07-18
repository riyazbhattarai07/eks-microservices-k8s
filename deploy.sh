#!/bin/bash
set -e

echo "🚀 EKS Microservices Deployment Script"
echo "======================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI not found${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform not found${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl not found${NC}"; exit 1; }

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Get AWS region
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter cluster name (default: microservices-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-microservices-cluster}

echo ""
echo "📦 Configuration:"
echo " Region: $AWS_REGION"
echo " Cluster: $CLUSTER_NAME"
echo ""

# Step 1: Deploy infrastructure
echo -e "${YELLOW}[1/4]${NC} Deploying EKS Infrastructure..."
cd terraform

terraform init -quiet
terraform plan -var="cluster_name=$CLUSTER_NAME" -var="aws_region=$AWS_REGION" -out=tfplan > /dev/null 2>&1

if terraform apply tfplan; then
  echo -e "${GREEN}✓ Infrastructure deployed${NC}"
  KUBECTL_CMD=$(terraform output -raw configure_kubectl)
  echo "Kubeconfig command: $KUBECTL_CMD"
else
  echo -e "${RED}❌ Infrastructure deployment failed${NC}"
  exit 1
fi

cd ..

# Step 2: Configure kubectl
echo ""
echo -e "${YELLOW}[2/4]${NC} Configuring kubectl..."
eval "$KUBECTL_CMD"
sleep 5

if kubectl cluster-info > /dev/null 2>&1; then
  echo -e "${GREEN}✓ kubectl configured and cluster accessible${NC}"
else
  echo -e "${RED}❌ kubectl configuration failed${NC}"
  exit 1
fi

# Step 3: Deploy applications
echo ""
echo -e "${YELLOW}[3/4]${NC} Deploying applications..."
cd k8s

for file in 01-*.yaml 02-*.yaml 03-*.yaml 04-*.yaml 05-*.yaml; do
  if [ -f "$file" ]; then
    echo " Applying $file..."
    kubectl apply -f "$file"
  fi
done

cd ..
echo -e "${GREEN}✓ Applications deployed${NC}"

# Step 4: Verify deployment
echo ""
echo -e "${YELLOW}[4/4]${NC} Verifying deployment..."
echo ""

echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/backend-api -n microservices --timeout=5m

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "📊 Deployment Status:"
echo "===================="
kubectl get pods -n microservices
echo ""
echo "🔗 Services:"
kubectl get svc -n microservices
echo ""
echo "⚙️ To access the backend API:"
echo " kubectl port-forward -n microservices svc/backend-api 8080:8080"
echo " Then visit: http://localhost:8080/health"
echo ""
echo "🔍 To monitor HPA:"
echo " kubectl get hpa -n microservices backend-api-hpa -w"
echo ""
echo "🗑️ To destroy infrastructure:"
echo " cd terraform && terraform destroy"
echo ""
