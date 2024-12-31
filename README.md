# EKS with ArgoCD and GitHub integration

## Project Overview

This guide focuses on deploying a Node.js application to an Amazon Elastic Kubernetes Service (EKS) cluster using ArgoCD for GitOps-style continuous deployment. The source code and manifests are managed on GitHub.

---

## Use Cases of ArgoCD
- 	**Continuous Deployment (CD)**: Automate deployments to Kubernetes clusters directly from Git.
- 	**GitOps Workflow**: Manage infrastructure and apps using Git as the single source of truth.
- 	**Multi-Cluster Management**: Deploy and sync apps across multiple Kubernetes clusters.
- 	**Environment-Specific Deployments**: Customize dev, stage, and prod environment configurations.
- 	**Progressive Delivery**: Implement canary or blue-green deployments for safer rollouts.
- 	**Drift Detection**: Identify and fix configuration drift automatically.
- 	**Infrastructure as Code**: Manage infrastructure and apps using tools like Helm or Terraform.
- 	**Secure Deployments**: Use Git-based RBAC for restricted permissions.
- 	**Audit and Compliance**: Track changes and enforce policies for compliance.
- 	**Disaster Recovery**: Restore apps and configurations after failures.
- 	**Multi-Cloud Support**: Manage Kubernetes clusters on AWS, Azure, GCP, and on-prem.

ArgoCD simplifies Kubernetes deployments with GitOps, enhancing automation, security, and scalability.

---

## Key Components:
1.  ECR: Managed Elastic Container Repository to host images. 
2.	EKS: Managed Kubernetes service for hosting the application.
3.	ArgoCD: GitOps tool to sync Kubernetes manifests from GitHub.
4.	GitHub: Repository for application source code and Kubernetes manifests.

---

## Run the Set Up Using a Bash Shell Script
- Create a bash shell script and add the content from **infra-setup.sh**.
```bash
# Create the file and add content.
touch setup.sh      # Create the setup and add the content below. 
touch cleanup.sh    # Create the setup and add the content below.
chmod +x setup.sh   # Make the script executable.
chmod +x cleanup.sh #  Make the script executable.
./infra-setup.sh    # Run the script.
./cleanup.sh        # Run the script.
```

**setup.sh**
```bash
#!/bin/bash

# Variables
AWS_REGION="us-east-1"
ECR_REPO_NAME="beginner2master-app"
EKS_CLUSTER_NAME="demo-cluster"
SSH_KEY_NAME="t2s-ssh-key"
ARGOCD_NAMESPACE="argocd"
AWS_ACCOUNT_ID="123456743435"

## Best Practice on Handling Variables. Input them on your local environment.
## Uncomment the commands below to do so. 
# export AWS_REGION="us-east-1"
# export ECR_REPO_NAME="beginner2master-app"
# export EKS_CLUSTER_NAME="demo-cluster"
# export SSH_KEY_NAME="t2s-ssh-key"
# export ARGOCD_NAMESPACE="argocd"
# export AWS_ACCOUNT_ID="12342321123"

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
```

**cleanup.sh**
```bash
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
```

---

## Step 1: Creating the ECR 
### Step 1.1: Prerequisites
- AWS CLI installed and configured with proper permissions.
- kubectl installed.

### Step 1.2: Create ECR and Push Docker Image to ECR
- Run this command to do it: 
```bash
aws ecr create-repository \
    --repository-name beginner2master-app \
    --region us-east-1
```

### Step 1.2: Create ECR
- Clone the repository to use:
```bash
git clone https://github.com/Here2ServeU/argocd-kubernetes-aws.git
cd docker-nodejs-webapp
```

- Authenticate Docker with ECR and Run the following command to log in to your AWS ECR:
```bash
aws ecr get-login-password --region <Region> | docker login --username AWS --password-stdin <Account-ID>.dkr.ecr.us-east-1.amazonaws.com
```

- Build the Docker image. Build the Docker image using the Dockerfile provided in the repository:
```bash
docker build -t beginner2master-app .
```

- Tag the Docker image.
```bash
docker tag beginner2master-app:latest <Account-ID>.dkr.ecr.<Region>.amazonaws.com/beginner2master-app:latest
```

- Push the Image to ECR. Push the Docker image to the ECR repository:
```bash
docker push <Account-ID>.dkr.ecr.<Region>.amazonaws.com/beginner2master-app:latest
```

## Step 2: Set Up the EKS Cluster

### Step 2.1: Prerequisites
- AWS CLI installed and configured with proper permissions.
- kubectl installed.
- eksctl installed for EKS provisioning.

### Step 2.2: Create the EKS Cluster
- Create the **t2s-ssh-key**.
```bash
aws ec2 create-key-pair --key-name t2s-ssh-key --query 'KeyMaterial' --output text > t2s-ssh-key.pem
```

- Run the following commands to create an EKS cluster:
```bash
eksctl create cluster \
  --name demo-cluster \
  --region us-east-1 \
  --nodes 2 \
  --node-type t3.medium \
  --with-oidc \
  --ssh-access \
  --ssh-public-key t2s-ssh-key \
  --managed
```
- Once the cluster is created, configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
```

- Verify the cluster is accessible:
```bash
kubectl get nodes
```
## Step 3: Deploy ArgoCD on EKS

#### Step 3.1: Install ArgoCD

- Apply the ArgoCD installation manifests:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
#### Step 3.2: Access ArgoCD UI

- Expose the ArgoCD server for external access:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- Access the UI at **https://localhost:8080**.

#### Step 3.3: Log in to ArgoCD

- Retrieve the default admin password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

- Use the username admin and the retrieved password to log in or create one that you desire:
```bash
kubectl patch secret argocd-initial-admin-secret -n argocd -p '{"stringData": {"password": "admin-t2s"}}'
```

## Step 4: Configure GitHub Repository

#### Step 4.1: Add Application Source Code
1.	Push your Node.js application code to a new GitHub repository: https://github.com/Here2ServeU/argocd-kubernetes-aws.

2.	Include the following Kubernetes manifest files in the repository:
- Deployment YAML: Defines the Node.js application deployment.
- Service YAML: Exposes the application as a ClusterIP or LoadBalancer.

3. Or, git clone this repo, https://github.com/Here2ServeU/argocd-kubernetes-aws.git.
```bash
git clone https://github.com/Here2ServeU/argocd-kubernetes-aws.git 
```

##### Deployment Manifest
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: t2s-nodejs-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: t2s-nodejs-app
  template:
    metadata:
      labels:
        app: t2s-nodejs-app
    spec:
      containers:
        - name: t2s-nodejs-app
          image: <ECR_URL>/beginner2master-app:latest
          ports:
            - containerPort: 3000
```
##### Service Manifest:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app
  namespace: default
spec:
  selector:
    app: nodejs-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
```

## Step 5: Deploy Application Using ArgoCD

#### Step 5.1: Add GitHub Repository
1.	Go to the ArgoCD UI.

2.	Create a new application:
     * Application Name: t2s-nodejs-app
     * Project: default
     * Repository URL: https://github.com/Here2ServeU/argocd-kubernetes-aws.git
     * Path: k8s-manifests (or the folder containing Kubernetes manifests)
     * Cluster: Your EKS cluster
     * Namespace: default

3.	Click Create.

#### Step 5.2: Sync Application
1.	Select the application in the ArgoCD UI.
2.	Click Sync to deploy the application to the EKS cluster.

* Verify the application is running:
```bash
kubectl get pods
kubectl get svc
```

## Step 6: Clean Up Resources

#### Clean Up Using the infra-setup.sh file
- Comment (#) steps 1 through 4.
- Uncomment the line "# cleanup" and rerun the script to clean up.
```bash
./infra-setup.sh
```

#### Step 6.1: Delete EKS Cluster
```bash
eksctl delete cluster --name demo-cluster
```
#### Step 6.2: Delete Docker Images and ECR

Delete unused images from ECR:
```bash
aws ecr batch-delete-image --repository-name beginner2master-app --image-ids imageTag=latest
aws ecr delete-repository --repository-name beginner2master-app --region us-east-1 --force
```
#### Step 6.3: Delete ArgoCD

Uninstall ArgoCD:
```bash
kubectl delete namespace argocd
```

#### Step 6.4: Clean Up Local Environment

Uninstall ArgoCD:
```bash
cd ..
rm -rf docker-nodejs-webapp/
```
---

This guide integrates EKS, ArgoCD, and GitHub Actions for seamless application deployment using Kubernetes on AWS. Feel free to let me know if you need further clarification!
