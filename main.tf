data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Fall back to the account's actual AZs if the ones in variables.tf don't
  # exist in the chosen region.
  azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------------------
# VPC — a small 2-AZ VPC dedicated to this test cluster (public + private
# subnets with no NAT gateway for a throwaway environment).
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS to auto-discover subnets for load balancers.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }
}

# ---------------------------------------------------------------------------
# EKS cluster — managed control plane + one managed node group.
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Gives the identity that ran `terraform apply` cluster-admin automatically
  # via an EKS access entry (modern replacement for the old aws-auth
  # ConfigMap approach).
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for entry in var.map_additional_iam_users :
    replace(entry.principal_arn, "/[^a-zA-Z0-9]/", "-") => {
      principal_arn = entry.principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = "SPOT"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "general"
      }
    }
  }

  # Useful cluster add-ons; versions are left unset so EKS picks the current
  # default compatible with cluster_version.
  cluster_addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {}
    aws-ebs-csi-driver = {}
  }
}

# ---------------------------------------------------------------------------
# IAM permissions the dashboard needs when running as a pod in-cluster
# (Kubernetes RBAC, not AWS IAM — the dashboard only reads the k8s API, it
# doesn't call any AWS APIs, so no IRSA role is required).
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "troubleshooter" {
  metadata {
    name = "k8s-ai-troubleshooter"
  }

  depends_on = [module.eks]
}
