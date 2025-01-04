variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.251.0.0/16"
}

variable "name_suffix" {
  type    = string
  default = "eks-hybrid-demo"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.251.1.0/24", "10.251.2.0/24", "10.251.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.251.4.0/24", "10.251.5.0/24", "10.251.6.0/24"]
}

variable "vpn_customer_gw" {
  type = string
}

variable "vpn_customer_worker_cidr" {
  type    = string
  default = "172.16.20.0/24"
}

variable "vpn_customer_pod_cidr" {
  type    = string
  default = "10.35.0.0/16"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "cluster_name" {
  type    = string
  default = "eks-hybrid-demo"
}

variable "service_cidr" {
  type    = string
  default = "10.36.0.0/16"
}

variable "node_groups" {
  description = "Each node group defined here is copied as many times as worker subnets AZs"
  type = list(object({
    name          = string
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = string
    disk_size     = number
    subnet_ids    = list(string)
  }))
  default = [{
    name          = ""
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    capacity_type = "SPOT"
    disk_size     = 20
    subnet_ids    = []
  }]
}

# Keep this optional
variable "enable_private_ingress_zone" {
  type    = bool
  default = false
}

variable "private_ingress_zone_domain" {
  type    = string
  default = "acme123.io"
}
