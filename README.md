# EKS test cluster (Terraform)

Spins up a small, throwaway EKS cluster for testing the AI Kubernetes
Troubleshooter against real cluster data. Uses the standard, widely-used
`terraform-aws-modules/vpc` and `terraform-aws-modules/eks` modules.

**This costs real money while it's running** — roughly $0.10/hr for the EKS
control plane plus ~$0.08/hr for two `t3.medium` nodes and a NAT gateway
(~$0.35–0.45/hr total, region-dependent). Destroy it when you're done
(`terraform destroy`); nothing here is sized for production use.

## Prerequisites

- Terraform >= 1.5 (`terraform version`)
- AWS CLI v2, configured with credentials that can create VPCs, EKS
  clusters, IAM roles, and EC2 instances (`aws sts get-caller-identity` to
  check)
- `kubectl`

## 1. Review variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region, cluster name, node size/count
```

Defaults are intentionally small (2× `t3.medium`, single NAT gateway) to
keep test-cluster cost down.

## 2. Apply

```bash
terraform init
terraform plan    # review what will be created
terraform apply   # takes ~12-15 minutes, mostly waiting on the EKS control plane
```

## 3. Point kubectl at the new cluster

```bash
$(terraform output -raw configure_kubectl)
# or manually:
aws eks update-kubeconfig --region <region> --name <cluster_name>

kubectl get nodes    # should show your node group, Ready
```

## 4. Deploy the dashboard onto it

From the repo root:

```bash
kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/deployment.yaml   # edit the image: field first, see below
```

To actually run the dashboard's own container image in-cluster, build and
push it to a registry the cluster can pull from (e.g. ECR) and update the
`image:` field in `k8s/deployment.yaml`:

```bash
aws ecr create-repository --repository-name k8s-ai-troubleshooter --region <region>
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com

docker build -t <account>.dkr.ecr.<region>.amazonaws.com/k8s-ai-troubleshooter:latest .
docker push <account>.dkr.ecr.<region>.amazonaws.com/k8s-ai-troubleshooter:latest
```

Optionally add your Claude API key so issues get full AI explanations
instead of the rule-based fallback:

```bash
kubectl create secret generic anthropic-api-key \
  -n k8s-ai-troubleshooter \
  --from-literal=ANTHROPIC_API_KEY=sk-ant-...
```

Get the dashboard's URL (the Service is type LoadBalancer):

```bash
kubectl get svc -n k8s-ai-troubleshooter k8s-ai-troubleshooter
# use the EXTERNAL-IP / hostname once it's provisioned (~1-2 min)
```

**Or, simpler for local testing:** skip building/pushing an image entirely
and just run the dashboard on your own machine pointed at this cluster —
since it already picked up `aws eks update-kubeconfig` in step 3, it'll read
the live cluster directly:

```bash
cd ../backend
pip install -r requirements.txt
python app.py
# open http://localhost:8000 — it should show "Live cluster", not "Demo data"
```

## 5. Generate real failures to test against

```bash
kubectl create namespace demo-failures
kubectl apply -n demo-failures -f ../k8s/sample-broken-workloads.yaml
```

This creates a CrashLoopBackOff pod, an ImagePullBackOff pod, an OOMKilled
pod, and a Pending/insufficient-cpu pod — the dashboard's Issues panel
should pick all four up within a refresh cycle (~20s).

Clean up the test workloads with:

```bash
kubectl delete namespace demo-failures
```

## 6. Tear down the cluster

Don't forget this step — the cluster bills hourly regardless of use:

```bash
kubectl delete -f ../k8s/deployment.yaml -f ../k8s/rbac.yaml   # if deployed in-cluster
terraform destroy
```

## What gets created

| Resource | Notes |
|---|---|
| VPC, 2 public + 2 private subnets, 1 NAT gateway | `terraform-aws-modules/vpc` |
| EKS control plane | version set by `cluster_version` (default 1.30) |
| Managed node group | 2× `t3.medium` on-demand by default |
| EKS access entry | grants the identity running `terraform apply` cluster-admin |
| Core add-ons | coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver |
| `k8s-ai-troubleshooter` namespace | created via the Kubernetes provider once the cluster is up |

## Notes

- `cluster_endpoint_public_access_cidrs` defaults to `0.0.0.0/0` (open) for
  simplicity — tighten it to your own IP (`curl -s ifconfig.me`) once you've
  confirmed `kubectl` connectivity works.
- IAM access is granted via EKS *access entries* (the modern approach), not
  the legacy `aws-auth` ConfigMap. Add teammates via
  `map_additional_iam_users` in `terraform.tfvars`.
- This was authored and reviewed for correctness but not run against a live
  AWS account from this session (no AWS credentials or Terraform binary
  available here) — run `terraform validate` and `terraform plan` yourself
  before applying, and sanity-check the plan output matches what's described
  above.
