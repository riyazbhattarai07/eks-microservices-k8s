# AWS EKS Microservices Architecture Portfolio Project

A production-ready Kubernetes deployment on AWS EKS demonstrating infrastructure-as-code, containerization, and DevOps best practices.

## Project Overview

This project implements a scalable microservices architecture on AWS Elastic Kubernetes Service (EKS) with:

- **Infrastructure as Code**: Terraform for reproducible VPC, EKS cluster, and node provisioning
- **Containerized Workloads**: Kubernetes deployments with proper RBAC, health checks, and resource management
- **Data Persistence**: MongoDB StatefulSet with persistent volumes for stateful workloads
- **Security**: NetworkPolicies, pod security contexts, least-privilege IAM roles
- **High Availability**: Multi-AZ deployment, auto-scaling, rolling updates
- **Observability**: Health checks, liveness/readiness probes, Prometheus metrics integration
- **Load Balancing**: AWS Application Load Balancer with Ingress integration

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  VPC (10.0.0.0/16)                  │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │         Public Subnets (us-east-1a,1b)      │   │  │
│  │  │  ┌─────────────┐  ┌─────────────┐           │   │  │
│  │  │  │  NAT GW 1   │  │  NAT GW 2   │           │   │  │
│  │  │  └─────────────┘  └─────────────┘           │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │        Private Subnets (us-east-1a,1b)      │   │  │
│  │  │  ┌────────────────────────────────────────┐ │   │  │
│  │  │  │       EKS Cluster (1.28)               │ │   │  │
│  │  │  │  ┌─────────────────────────────────┐   │ │   │  │
│  │  │  │  │    Backend API (2-5 replicas)   │   │ │   │  │
│  │  │  │  │    - HPA enabled                │   │ │   │  │
│  │  │  │  │    - Prometheus metrics         │   │ │   │  │
│  │  │  │  └─────────────────────────────────┘   │ │   │  │
│  │  │  │  ┌─────────────────────────────────┐   │ │   │  │
│  │  │  │  │  MongoDB StatefulSet (1 replica)│   │ │   │  │
│  │  │  │  │  - PersistentVolume (10Gi)      │   │ │   │  │
│  │  │  │  └─────────────────────────────────┘   │ │   │  │
│  │  │  └────────────────────────────────────────┘ │   │  │
│  │  │  Node Group: 2-4 t3.medium instances       │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          AWS Application Load Balancer              │  │
│  │        (External access, SSL/TLS termination)       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Kubernetes Features Demonstrated

### 1. **Pod Lifecycle Management**
- Liveness probes (automatic pod restart on failure)
- Readiness probes (prevents traffic to unready pods)
- Graceful shutdown with preStop hooks
- Rolling updates with maxSurge/maxUnavailable

### 2. **Resource Management**
- CPU/Memory requests and limits
- Horizontal Pod Autoscaler (HPA) with custom metrics
- Scale-down stabilization to prevent flapping

### 3. **Security**
- Pod Security Context (non-root user, read-only filesystem where possible)
- NetworkPolicies (default deny, explicit allow rules)
- RBAC with least-privilege service accounts
- No privileged containers

### 4. **Observability**
- Prometheus-compatible metrics endpoints
- Health check endpoints for ALB
- Container logs to CloudWatch
- Pod and node monitoring ready

### 5. **Data Persistence**
- StatefulSet for MongoDB with ordered deployment
- PersistentVolumeClaim for data durability
- Configuration management via ConfigMaps

### 6. **Infrastructure Quality**
- Multi-AZ deployment for fault tolerance
- Terraform modules for reusability
- Version pinning for reproducibility
- Proper tagging and labeling

## Deployment Instructions

### Prerequisites

```bash
# Required tools
aws-cli >= 2.0
terraform >= 1.0
kubectl >= 1.28
eksctl (optional, for troubleshooting)
```

### Step 1: Configure AWS Credentials

```bash
aws configure
# Provide: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### Step 2: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform working directory
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure changes
terraform apply tfplan

# Save outputs for kubectl configuration
terraform output configure_kubectl > /tmp/kubectl_config.sh
```

### Step 3: Configure kubectl

```bash
# Run the command output from Terraform
$(cat /tmp/kubectl_config.sh)

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Step 4: Deploy Applications

```bash
cd ../k8s

# Apply manifests in order
kubectl apply -f 01-namespace-rbac.yaml
kubectl apply -f 02-backend-api.yaml
kubectl apply -f 03-mongodb-statefulset.yaml
kubectl apply -f 04-network-policies.yaml
kubectl apply -f 05-ingress.yaml

# Verify deployments
kubectl get deployments -n microservices
kubectl get pods -n microservices
kubectl get svc -n microservices
```

### Step 5: Verify Deployment

```bash
# Check pod health
kubectl get pods -n microservices -o wide

# Check logs
kubectl logs -n microservices deployment/backend-api

# Test backend API
kubectl port-forward -n microservices svc/backend-api 8080:8080
curl http://localhost:8080/health

# Get ALB DNS name (for external access)
kubectl get ingress -n microservices api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Scaling and Monitoring

### Manual Scaling

```bash
# Scale backend API
kubectl scale deployment -n microservices backend-api --replicas=3

# Check HPA status
kubectl get hpa -n microservices backend-api-hpa
```

### View Metrics

```bash
# CPU/Memory usage
kubectl top nodes
kubectl top pods -n microservices

# HPA events
kubectl describe hpa -n microservices backend-api-hpa
```

## Cost Optimization

This deployment demonstrates cost-conscious design:

- **Node auto-scaling**: Only pay for nodes you use
- **Pod HPA**: Automatic scaling down during low traffic
- **Resource limits**: Prevents runaway resource consumption
- **t3.medium instances**: Cost-effective for dev/test

Monthly estimate (us-east-1):
- EKS control plane: ~$73
- 2 t3.medium nodes (on-demand): ~$60-80
- Data storage (10Gi): ~$1
- **Estimated total**: $134-154/month

Use Spot instances to reduce node costs by 70%.

## Troubleshooting

### Pods not starting?

```bash
kubectl describe pod <pod-name> -n microservices
kubectl logs <pod-name> -n microservices
```

### Node issues?

```bash
kubectl get nodes
kubectl describe node <node-name>
aws ec2 describe-instances --instance-ids <instance-id>
```

### Ingress not working?

```bash
kubectl describe ingress -n microservices api-ingress
# Verify ALB controller is installed and running in kube-system namespace
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Security Best Practices Implemented

1. ✅ Network segmentation via NetworkPolicies
2. ✅ Pod security contexts (non-root, capability dropping)
3. ✅ RBAC with minimal permissions
4. ✅ Health checks to detect compromised containers
5. ✅ Resource limits to prevent DoS
6. ✅ CloudWatch logging for audit trails
7. ✅ IAM roles for fine-grained AWS access

## Production Improvements

For production deployments, consider adding:

1. **Multi-region failover** with Route 53
2. **ArgoCD** for GitOps continuous deployment
3. **Prometheus + Grafana** for full observability stack
4. **Cert-Manager** for automated TLS certificate management
5. **EBS snapshots** for automated backups
6. **Network Encryption** with Calico or Cilium
7. **Pod Disruption Budgets** for controlled maintenance
8. **Vertical Pod Autoscaler** for right-sizing recommendations

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace microservices

# Destroy AWS infrastructure
cd terraform
terraform destroy
```

## Learning Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Project Files

```
eks-microservices-k8s/
├── terraform/
│   ├── main.tf              # VPC, EKS cluster, node groups
│   ├── variables.tf         # Input variables
│   └── outputs.tf           # Output values
├── k8s/
│   ├── 01-namespace-rbac.yaml      # Namespace and RBAC
│   ├── 02-backend-api.yaml         # API deployment with HPA
│   ├── 03-mongodb-statefulset.yaml # MongoDB persistence
│   ├── 04-network-policies.yaml    # Security policies
│   └── 05-ingress.yaml             # External load balancing
├── deploy.sh                # One-click deployment script
└── README.md                # This file
```

## Author Notes

This project demonstrates comprehensive understanding of:
- Kubernetes resource management and pod lifecycle
- Terraform for infrastructure provisioning
- AWS networking (VPC, subnets, NAT, security groups)
- EKS cluster architecture and best practices
- Container security and NetworkPolicies
- Production-grade deployment patterns
- Auto-scaling and self-healing capabilities

All configurations follow AWS and Kubernetes best practices for security, reliability, and cost efficiency.
