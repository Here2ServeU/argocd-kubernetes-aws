#!/bin/bash

# Variables
AWS_REGION="us-east-1"
ECR_REPO_NAME="beginner2master-app"
EKS_CLUSTER_NAME="demo-cluster"
SSH_KEY_NAME="t2s-ssh-key"
ARGOCD_NAMESPACE="argocd"


# Cleanup Function
function cleanup() {
  echo "Starting cleanup process..."

  # Step 1: Delete EKS Cluster
  echo "Deleting EKS cluster..."
  eksctl delete cluster --name $EKS_CLUSTER_NAME

  # Step 2: Delete ECR Repository and Images
  echo "Deleting ECR images and repository..."
  aws ecr batch-delete-image --repository-name $ECR_REPO_NAME --image-ids imageTag=latest 2>/dev/null || echo "No images found in repository."
  aws ecr delete-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --force

  # Step 3: Uninstall ArgoCD
  echo "Uninstalling ArgoCD..."
  kubectl delete namespace $ARGOCD_NAMESPACE || echo "ArgoCD namespace not found."

  # Step 4: Delete Local SSH Key and Repository
  echo "Cleaning up local environment..."
  rm -f ${SSH_KEY_NAME}.pem
  rm -rf argocd-kubernetes-aws/

  echo "Cleanup process completed successfully."
}

# Execute Cleanup
cleanup
