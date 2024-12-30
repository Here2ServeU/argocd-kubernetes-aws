#!/bin/bash

# Variables
## Replace variables as desired
AWS_REGION="us-east-1"
ECR_REPO_NAME="beginner2master-app"
EKS_CLUSTER_NAME="demo-cluster"
SSH_KEY_NAME="t2s-ssh-key"
ARGOCD_NAMESPACE="argocd"
AWS_ACCOUNT_ID="12342321123"

# Step 1: Create ECR Repository
echo "Creating ECR repository..."
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION

# Clone GitHub repository
echo "Cloning GitHub repository..."
git clone https://github.com/Here2ServeU/argocd-kubernetes-aws.git
cd argocd-kubernetes-aws

# Authenticate Docker with ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and Push Docker Image to ECR
echo "Building Docker image..."
docker build -t $ECR_REPO_NAME .
docker tag $ECR_REPO_NAME:latest ${AWS_ACCOUNT_ID}.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Step 2: Create EKS Cluster
echo "Creating EC2 SSH Key Pair..."
aws ec2 create-key-pair --key-name $SSH_KEY_NAME --query 'KeyMaterial' --output text > ${SSH_KEY_NAME}.pem
chmod 400 ${SSH_KEY_NAME}.pem

echo "Creating EKS cluster..."
eksctl create cluster \
  --name $EKS_CLUSTER_NAME \
  --region $AWS_REGION \
  --nodes 2 \
  --node-type t3.medium \
  --with-oidc \
  --ssh-access \
  --ssh-public-key $SSH_KEY_NAME \
  --managed

# Update kubeconfig
echo "Updating kubeconfig for EKS cluster..."
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# Verify nodes
echo "Verifying EKS cluster nodes..."
kubectl get nodes

# Step 3: Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace $ARGOCD_NAMESPACE
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD server
echo "Exposing ArgoCD server..."
kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 &

# Set ArgoCD admin password
echo "Setting ArgoCD admin password..."
kubectl patch secret argocd-initial-admin-secret -n $ARGOCD_NAMESPACE -p '{"stringData": {"password": "admin-t2s"}}'

# Step 4: Deploy Application Using ArgoCD
echo "Configuring ArgoCD application..."
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Step 5: Clean Up Resources
function cleanup() {
  echo "Deleting EKS cluster..."
  eksctl delete cluster --name $EKS_CLUSTER_NAME

  echo "Deleting ECR repository..."
  aws ecr batch-delete-image --repository-name $ECR_REPO_NAME --image-ids imageTag=latest
  aws ecr delete-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --force

  echo "Uninstalling ArgoCD..."
  kubectl delete namespace $ARGOCD_NAMESPACE

  echo "Cleaning up local environment..."
  cd ..
  rm -rf argocd-kubernetes-aws/
  rm -f ${SSH_KEY_NAME}.pem
}

# Uncomment the line below to clean up resources automatically after the script completes
# cleanup

echo "Setup complete. Visit https://localhost:8080 for the ArgoCD UI."
