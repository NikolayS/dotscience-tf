variable "region" {
  # only supported zone for devel dotscience cft builds is us-east-1
  default = "us-east-1"
}

variable "dotscience_hub_ssh_key" {
  default = "luke-us-east-1"
}

variable "dotscience_hub_ingress_cidr" {
  default = "0.0.0.0/0"
}

variable "dotscience_ssh_access_cidr" {
  default = "0.0.0.0/0"
}

variable "dotscience_hub_admin_password" {
  default = "insecure_do_not_use"
}

# Default config, hub = 1x t3.small, EKS cluster = 2x t3.small
# plus whatever runners you create after logging in
# Total = $0.02 * 3 = $0.06/hour, or $43/month for compute
# Storage defaults to 1TB of gp2 storage, ($0.1/GB, so $102/month)
# So default stack should be $145/month + burstable compute for runners.

variable "dotscience_hub_instance_type" {
  default = "t3.small"
}

variable "dotscience_hub_volume_size_gb" {
  default = 1024
}

variable "eks_cluster_worker_instance_type" {
  default = "t3.small"
}

variable "eks_cluster_worker_count" {
  default = 2
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = [
#    "777777777777",
#    "888888888888",
  ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
#    {
#      rolearn  = "arn:aws:iam::66666666666:role/role1"
#      username = "role1"
#      groups   = ["system:masters"]
#    },
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
#    {
#      userarn  = "arn:aws:iam::66666666666:user/user1"
#      username = "user1"
#      groups   = ["system:masters"]
#    },
#    {
#      userarn  = "arn:aws:iam::66666666666:user/user2"
#      username = "user2"
#      groups   = ["system:masters"]
#    },
  ]
}