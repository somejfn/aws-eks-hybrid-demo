variable "pve_host" {
  type    = string
  default = "10.0.0.150"
}

variable "pve_name" {
  type    = string
  default = "virthost"
}

variable "hybrid_nodes_subnet" {
  type    = string
  default = "172.16.20"
}

variable "hybrid_nodes_template" {
  type    = string
  default = "AL2023"
}

variable "hybrid_nodes_name_prefix" {
  type    = string
  default = "eks"
}

variable "hybrid_nodes_count" {
  type    = number
  default = 3
}

variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "aws_eks_cluster_name" {
  type    = string
  default = "eks-hybrid-demo"
}

variable "aws_eks_cluster_version" {
  type    = string
  default = "1.31"
}


variable "aws_ssm_activation_id" {
  type = string
}

variable "aws_ssm_activation_code" {
  type = string
}

variable "ssh_pub_key" {
  type    = string
}
