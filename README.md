# EKS with ArgoCD and GitHub integration

## Project Overview

This guide focuses on deploying a Node.js application to an Amazon Elastic Kubernetes Service (EKS) cluster using ArgoCD for GitOps-style continuous deployment. The source code and manifests are managed on GitHub.

---

## Use Cases of ArgoCD
- 	**Continuous Deployment (CD)**: Automate deployments to Kubernetes clusters directly from Git.
- 	**GitOps Workflow**: Manage infrastructure and apps using Git as the single source of truth.
- 	**Multi-Cluster Management**: Deploy and sync apps across multiple Kubernetes clusters.
- 	**Environment-Specific Deployments**: Customize dev, stage, and prod environments configurations.
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
touch infra-setup.sh     # Create the file and add content. 
chmod +x infra-setup.sh  # Make the script executable. 
./infra-setup.sh         # Run the script.
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
