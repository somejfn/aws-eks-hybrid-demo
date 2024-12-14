# aws-eks-hybrid-demo
Demonstration of AWS' EKS hybrid nodes using Promox on-premises

I used these terraform samples to rapidly build/destroy a test environment made of:
* A new VPC with 3 private subnets for EKS and 3 public subnets for internet access via a single NAT gateway
* A site to site VPN to an on-premise network (the router is a Proxmox VM running debian/libreswan)
* A private EKS cluster ready to add Amazon linux hybrid nodes using SSM

From there I could test a series of things where I kept the Kubernetes related files (under k8s) to test hybrid scenarios such as
* Load balancing from onprem with MetalLB and NLBs/ALBs from AWS
* Persistent storage with Proxmox CSI drivers and EBS in AWS



