variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag (e.g. test, dev)"
  type        = string
  default     = "test"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "k8s-ai-troubleshooter-test"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created for this cluster"
  type        = string
  default     = "10.42.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes (kept small to minimize cost for a test cluster)"
  type        = number
  default     = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the public internet (true is simplest for a personal test cluster; restrict cluster_endpoint_public_access_cidrs in real use)"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Tighten this to your own IP/32 for anything beyond throwaway testing."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "map_additional_iam_users" {
  description = "Extra IAM users/roles to grant cluster-admin access via EKS access entries, beyond the identity running terraform apply. Example: [{ principal_arn = \"arn:aws:iam::123456789012:user/jane\" }]"
  type = list(object({
    principal_arn = string
  }))
  default = []
}
