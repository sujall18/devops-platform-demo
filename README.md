# devops-platform-demo

A production-style deployment platform built to demonstrate end-to-end DevOps engineering: a containerised API deployed to Kubernetes on AWS, provisioned with Terraform, shipped via GitHub Actions CI/CD, and observed with Prometheus and Grafana.

---

## What this demonstrates

| Layer | Technology |
|---|---|
| Application | Python Flask REST API, PostgreSQL |
| Containerisation | Multi-stage Docker build, non-root runtime user |
| Local dev | Docker Compose, pgAdmin, Makefile |
| Infrastructure as Code | Terraform (modules, remote state on S3, DynamoDB locking) |
| Compute | k3s on AWS EC2 `t2.micro` (free-tier) |
| Kubernetes | Deployment, StatefulSet, Service, ConfigMap, Secret, Ingress, probes, resource limits |
| CI/CD | GitHub Actions — lint → test → build → push to GHCR → deploy to k3s |
| Security | Trivy container scanning (CRITICAL/HIGH gate), results in GitHub Security tab |
| Observability | Prometheus pod auto-discovery, Grafana RED dashboard (rate / errors / duration) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub                                                     │
│  ┌──────────┐  push to main  ┌─────────────────────────┐   │
│  │  Source  │ ─────────────► │  GitHub Actions         │   │
│  │  Code    │                │  ci.yml  → lint + test  │   │
│  └──────────┘                │  cd.yml  → build + push │   │
│                              │  terraform.yml → plan   │   │
│                              │  security-scan → trivy  │   │
│                              └────────────┬────────────┘   │
└───────────────────────────────────────────│─────────────────┘
                                            │ SSH deploy
                              ┌─────────────▼────────────────┐
                              │  AWS (us-east-1)             │
                              │  ┌──────────────────────┐    │
                              │  │  VPC  10.0.0.0/16    │    │
                              │  │  ┌────────────────┐  │    │
                              │  │  │ EC2 t2.micro   │  │    │
                              │  │  │ k3s cluster    │  │    │
                              │  │  │                │  │    │
                              │  │  │ ┌────────────┐ │  │    │
                              │  │  │ │task-tracker│ │  │    │
                              │  │  │ │  x2 pods   │ │  │    │
                              │  │  │ └─────┬──────┘ │  │    │
                              │  │  │       │        │  │    │
                              │  │  │ ┌─────▼──────┐ │  │    │
                              │  │  │ │ PostgreSQL  │ │  │    │
                              │  │  │ │StatefulSet │ │  │    │
                              │  │  │ └────────────┘ │  │    │
                              │  │  │                │  │    │
                              │  │  │ ┌────────────┐ │  │    │
                              │  │  │ │ Prometheus  │ │  │    │
                              │  │  │ │  + Grafana  │ │  │    │
                              │  │  │ └────────────┘ │  │    │
                              │  │  └────────────────┘  │    │
                              │  └──────────────────────┘    │
                              │                              │
                              │  S3 (Terraform remote state) │
                              │  DynamoDB (state lock)       │
                              └──────────────────────────────┘
```

---

## Prerequisites

- Docker + Docker Compose
- `make`
- AWS CLI configured (`aws configure`)
- Terraform >= 1.7
- An AWS key pair (for SSH into EC2)

---

## Run locally

```bash
cp .env.example .env
make dev
# App: http://localhost:5000
# pgAdmin: http://localhost:8080  (admin@local.dev / admin)
```

Test the API:
```bash
curl http://localhost:5000/health
curl http://localhost:5000/tasks
curl -X POST http://localhost:5000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Ship to production"}'
```

Run tests locally:
```bash
make test
make lint
```

---

## Deploy to AWS

### 1. Bootstrap Terraform state backend (one-time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the output: state_bucket and lock_table values
```

### 2. Configure backend and variables

```bash
cp terraform/backend.hcl.example terraform/backend.hcl
# Edit backend.hcl with the bucket/table names from step 1

cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars: set key_name and my_ip_cidr
```

### 3. Provision infrastructure

```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
# Note the output: instance_public_ip and ssh_command
```

### 4. Deploy Kubernetes workloads

```bash
# SSH into the instance (use the ssh_command from terraform output)
ssh -i ~/.ssh/<key>.pem ubuntu@<PUBLIC_IP>

# On the EC2 instance:
git clone https://github.com/<YOUR_USER>/devops-platform-demo
cd devops-platform-demo
kubectl apply -f k8s/base/
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/grafana/
```

### 5. Configure GitHub Actions secrets

In your GitHub repo → Settings → Secrets:

| Secret | Value |
|---|---|
| `K3S_HOST` | EC2 public IP |
| `K3S_SSH_KEY` | Contents of your private key file |
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `TF_KEY_NAME` | Name of your AWS key pair |

After secrets are set, every push to `main` triggers an automated deploy.

---

## Access running services

```bash
# App API
curl http://<EC2_PUBLIC_IP>:30080/tasks

# Grafana dashboard
open http://<EC2_PUBLIC_IP>:30300   # admin / admin
```

---

## Design decisions

**k3s instead of EKS**

EKS costs a minimum of $0.10/hour (~$72/month) for the control plane alone, before any EC2 costs. k3s is a CNCF-certified Kubernetes distribution that runs on a single `t2.micro` (free-tier eligible). For a portfolio project the goal is to demonstrate Kubernetes operator skills — writing Deployments, debugging pods, managing Services and Ingress — not to pay for a managed control plane. k3s provides identical `kubectl` semantics. Any real employer will understand this tradeoff.

**GHCR instead of Docker Hub**

GitHub Container Registry is free for public images, integrates with `GITHUB_TOKEN` (no extra secret needed for pushes), and sits in the same ecosystem as the CI/CD. Docker Hub has rate-limited pulls since 2020 which can break pipelines unpredictably.

**GitOps image tag update**

The `cd.yml` workflow commits the new image SHA back to `k8s/base/deployment.yaml` before deploying. This means the manifest in `main` always reflects what is running — you can see the deployed version in git history without logging into the cluster.

**Trivy weekly cron scan**

Container base images accumulate CVEs after you build them. A weekly scan (`cron: "0 6 * * 1"`) catches newly disclosed vulnerabilities in the base image even when no code changes have been pushed.

**Terraform module structure**

Infrastructure is split into `networking` and `compute` modules so each can be evolved or replaced independently. Remote state with S3 + DynamoDB locking is the standard pattern for any team — state conflicts without a lock table cause corruption on concurrent `apply` runs.

---

## CI/CD pipeline overview

```
PR opened
  └── ci.yml
        ├── flake8 lint
        ├── pytest (sqlite in-memory, no real DB needed)
        └── docker build (cache-only, no push)

Push to main
  ├── cd.yml
  │     ├── docker build + push to GHCR (SHA-tagged)
  │     ├── sed image tag in deployment.yaml + git commit
  │     └── SSH → kubectl apply → rollout status check
  ├── terraform.yml (if terraform/** changed)
  │     ├── fmt check + validate + plan
  │     └── apply (on main push only)
  └── security-scan.yml (if app/** or Dockerfile changed)
        ├── trivy scan — CRITICAL/HIGH gate
        └── upload SARIF to GitHub Security tab
```

---

## Repository structure

```
devops-platform-demo/
├── app/                         Flask application + tests
│   ├── app.py
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── tests/
├── Dockerfile                   Multi-stage, non-root runtime
├── docker-compose.yml           Local dev: app + postgres + pgadmin
├── Makefile                     dev / build / push / test / lint
├── .github/workflows/
│   ├── ci.yml                   Lint + test + build on PRs
│   ├── cd.yml                   Build + push + deploy on main
│   ├── terraform.yml            Plan on PR, apply on main
│   └── security-scan.yml        Trivy weekly + on Dockerfile changes
├── terraform/
│   ├── main.tf                  Root module — calls networking + compute
│   ├── variables.tf
│   ├── outputs.tf
│   ├── bootstrap/               One-time S3 + DynamoDB setup
│   └── modules/
│       ├── networking/          VPC, subnet, IGW, route table
│       └── compute/             EC2, security group, IAM role, k3s user_data
└── k8s/
    ├── base/                    App manifests (namespace → ingress)
    └── monitoring/
        ├── prometheus/          Deployment + ClusterRole + scrape config
        └── grafana/             Deployment + RED dashboard provisioned via ConfigMap
```

---

## License

MIT
