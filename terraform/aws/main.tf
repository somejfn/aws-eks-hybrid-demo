provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Name = var.name_suffix
  }
  eks_nodegroups = [
    for pair in setproduct(var.node_groups, aws_subnet.private_subnets[*].id) : merge(pair[0], { subnet_ids = [pair[1]] })
  ]
}

module "eks" {
  source                    = "terraform-aws-modules/eks/aws"
  version                   = "20.31.4"
  cluster_name              = var.name_suffix
  cluster_version           = var.cluster_version
  cluster_service_ipv4_cidr = var.service_cidr

  bootstrap_self_managed_addons = false

  cluster_endpoint_public_access           = false
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  create_node_security_group = true

  # Workaround for https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1986
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = null
  }

  cluster_security_group_additional_rules = {
    hybrid-all = {
      cidr_blocks = [var.vpn_customer_worker_cidr, var.vpn_customer_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  node_security_group_additional_rules = {
    hybrid-to-ec2 = {
      cidr_blocks = [var.vpn_customer_worker_cidr, var.vpn_customer_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
    alb-to-ec2 = {
      cidr_blocks = var.private_subnet_cidrs
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  access_entries = {
    hybrid-node-role = {
      principal_arn = module.eks_hybrid_node_role.arn
      type          = "HYBRID_LINUX"
    }
    root = {
      principal_arn = "arn:aws:iam::${local.account_id}:root"
      type          = "STANDARD"
      policy_associations = {
        cluster_manager = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            namespaces = []
            type       = "cluster"
          }

        }

      }
    }
  }

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private_subnets[*].id

  cluster_remote_network_config = {
    remote_node_networks = {
      cidrs = [var.vpn_customer_worker_cidr]
    }
    remote_pod_networks = {
      cidrs = [var.vpn_customer_pod_cidr]
    }
  }

  tags = local.tags
}

module "eks_hybrid_node_role" {
  source          = "terraform-aws-modules/eks/aws//modules/hybrid-node-role"
  cluster_arns    = [module.eks.cluster_arn]
  name            = "EKSHybridNode"
  use_name_prefix = false
  tags = {
    ClusterName = var.cluster_name
  }
}


module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.31.4"

  for_each                          = { for idx, ng in local.eks_nodegroups : idx => ng }
  name                              = "system"
  cluster_name                      = var.name_suffix
  cluster_version                   = var.cluster_version
  cluster_service_ipv4_cidr         = var.service_cidr
  subnet_ids                        = each.value.subnet_ids
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]
  min_size                          = 1
  max_size                          = 3
  desired_size                      = 1

  instance_types = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
  capacity_type  = "SPOT"
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_eks_addon" "cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [module.eks_managed_node_group]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [resource.aws_eks_addon.cni]
}

resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [resource.aws_eks_addon.cni]
}

module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "aws-lbc"

  attach_aws_lb_controller_policy = true

  # Pod Identity Associations
  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller-sa"
  }

  associations = {
    ex-one = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = {
    Environment = "dev"
  }
}


module "external_dns_pod_identity" {
  count  = var.enable_private_ingress_zone == true ? 1 : 0
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [aws_route53_zone.private[0].arn]

  # Pod Identity Associations
  association_defaults = {
    namespace       = "external-dns"
    service_account = "external-dns-sa"
  }

  associations = {
    ex-one = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_ssm_activation" "test" {
  name               = "test_ssm_activation"
  description        = "Test"
  iam_role           = module.eks_hybrid_node_role.name
  registration_limit = "5"
  depends_on         = [module.eks_hybrid_node_role]
}

output "ssm_activation" {
  value = resource.aws_ssm_activation.test
}