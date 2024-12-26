provider "proxmox" {
  pm_api_url      = "https://${var.pve_host}:8006/api2/json"
  pm_tls_insecure = true
}


resource "proxmox_cloud_init_disk" "test" {
  count    = var.hybrid_nodes_count
  name     = "${var.hybrid_nodes_name_prefix}-${count.index + 1}"
  pve_node = var.pve_name
  storage  = "local"
  meta_data = yamlencode({
    instance_id    = sha1("${var.hybrid_nodes_name_prefix}-${count.index + 1}")
    local-hostname = "${var.hybrid_nodes_name_prefix}-${count.index + 1}"
  })

  user_data = <<-EOT
  #cloud-config
  users:
    - default
  ssh_authorized_keys:
    - ${var.ssh_pub_key}
  write_files:
  - path: /root/nodeConfig.yaml
    content: |
      apiVersion: node.eks.aws/v1alpha1
      kind: NodeConfig
      spec:
        cluster:
          name: ${var.aws_eks_cluster_name}
          region: ${var.aws_region}
        hybrid:
          ssm:
            activationCode: ${var.aws_ssm_activation_code}
            activationId: ${var.aws_ssm_activation_id}
        kubelet:
          flags:
            - --node-labels=proxmox.com/vmname="${var.hybrid_nodes_name_prefix}-${count.index + 1}",topology.kubernetes.io/zone="${var.hybrid_nodes_topology_zone}"
    owner: 'root:root'
    permissions: '0640'
  runcmd:
    - curl -OL 'https://hybrid-assets.eks.amazonaws.com/releases/latest/bin/linux/amd64/nodeadm'
    - chmod a+x ./nodeadm
    - ./nodeadm install ${var.aws_eks_cluster_version} --credential-provider ssm
    - ./nodeadm init -c file:///root/nodeConfig.yaml
  EOT

  network_config = yamlencode({
    version = 1
    config = [{
      type = "physical"
      name = "ens18"
      subnets = [{
        type    = "static"
        address = "${var.hybrid_nodes_subnet}.${count.index + 101}/24"
        gateway = "${var.hybrid_nodes_subnet}.1"
        dns_nameservers = [
          "8.8.8.8"
        ]
      }]
    }]
  })
}

resource "proxmox_vm_qemu" "cloudinit-test" {
  count       = var.hybrid_nodes_count
  name        = "${var.hybrid_nodes_name_prefix}-${count.index + 1}"
  desc        = "EKS hybrd nodes"
  target_node = var.pve_name
  clone       = var.hybrid_nodes_template
  os_type     = "cloud-init"
  cores       = 2
  memory      = 2048
  scsihw      = "virtio-scsi-single"
  bootdisk    = "scsi0"
  boot        = "order=scsi0;net0;scsi1"

  # Hackish way to store the IP for destroy provisioner
  ipconfig0 = "${var.hybrid_nodes_subnet}.${count.index + 101}"

  # Setup the disk
  disks {
    scsi {
      scsi0 {
        disk {
          size    = 25
          storage = "local-lvm"
        }
      }
      scsi1 {
        cdrom {
          iso = proxmox_cloud_init_disk.test[count.index].id
        }
      }
    }
  }


  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr1"
  }

  # Something buggy about this
  lifecycle {
    ignore_changes = [bootdisk]
  }

  # To Unregister from SSM on destroy
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.ipconfig0
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline     = ["sudo /nodeadm uninstall --skip node-validation --skip pod-validation"]
  }

}