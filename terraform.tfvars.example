# Copy to terraform.tfvars and adjust, or pass these as -var flags.

aws_region      = "us-east-1"
cluster_name    = "k8s-ai-troubleshooter-test"
cluster_version = "1.30"

# Cheapest reasonable test setup: one Spot node.
node_instance_types = ["t3.small", "t3a.small"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 1

# Lock this down to your own IP once you've confirmed connectivity, e.g.:
# cluster_endpoint_public_access_cidrs = ["203.0.113.4/32"]
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
