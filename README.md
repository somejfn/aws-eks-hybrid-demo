# aws-eks-hybrid-demo
Demonstration of AWS' EKS hybrid nodes using Promox on-premises

I used these terraform samples to rapidly build/destroy a test environment made of:
* A new VPC with 3 private subnets for EKS and 3 public subnets for internet access via a single NAT gateway
* A site to site VPN to an on-premise network (the router is a Proxmox VM running debian/libreswan)
* A private EKS cluster ready to add Amazon linux hybrid nodes using SSM

From there I could test a series of things where I kept the Kubernetes related files (under k8s) to test hybrid scenarios such as
* Load balancing from onprem with MetalLB and NLBs/ALBs from AWS
* Persistent storage with Proxmox CSI drivers and EBS in AWS

I used the AWS CNI in its default configuration for EC2 node pool and Cilium CNI for the onprem nodes.  Static routing is used in this setup,  meaning the router on onprem side knows how to reach the POD CIDR through the worker node.

Once this infrastructure is deployed, you can generate tempory SSM credentials to bootstrap the Promox hosted Amazon Linux VM.


The EKSHybrid Role used below was the one created from Terraform

```
aws ssm create-activation \
     --region ca-central-1 \
     --default-instance-name eks-hybrid-nodes \
     --description "Activation for EKS hybrid nodes" \
     --iam-role EKSHybridNode-20241214161029171800000001  \
     --tags Key=Name,Value=eks-hybrid-demo \
     --registration-limit 10
```

Then on the Amazon Linux VM

```
curl -OL 'https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm'
chmod a+x ./nodeadm 
./nodeadm install 1.31 --credential-provider ssm

ACTIVATION_CODE="<passed via cloud-init>"
ACTIVATION_ID="<passed via cloud-init>"
CLUSTER_NAME=eks-hybrid-demo
AWS_REGION=<region>

cat <<EOF> nodeConfig.yaml
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    region: $AWS_REGION
  hybrid:
    ssm:
      activationCode: $ACTIVATION_CODE
      activationId: $ACTIVATION_ID
EOF

nodeadm init -c file://nodeConfig.yaml
```

Et voila !   You can now deploy CNI/CSI drivers and load balancer controllers.

TODO: 
* Boostrap the Proxmox VM via cloud-init
* Autoscaling Proxmox nodes
* Private DNS for external-dns
