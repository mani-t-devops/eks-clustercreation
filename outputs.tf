output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "region" {
  value = var.aws_region
}

output "configure_kubectl" {
  description = "Command to point kubectl/the dashboard's kubeconfig at this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "node_group_status" {
  value = { for k, v in module.eks.eks_managed_node_groups : k => v.node_group_status }
}
