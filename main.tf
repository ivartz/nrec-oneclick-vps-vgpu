provider "openstack" {
  insecure = true
}

resource "random_string" "suffix" {
  count   = var.deployment_id == "" ? 1 : 0
  length  = 6
  upper   = false
  numeric = true
  special = false
}

locals {
  deployment_id       = var.deployment_id != "" ? var.deployment_id : "hermes-${random_string.suffix[0].result}"
  private_key         = "${path.module}/${var.keys_dir}/${local.deployment_id}.pem"
  operator_cidr       = var.operator_public_ip != "" ? "${var.operator_public_ip}/32" : "0.0.0.0/0"
  has_ipv6            = var.operator_public_ipv6 != ""
  operator_ipv6_cidr  = var.operator_public_ipv6 != "" ? "${var.operator_public_ipv6}/128" : ""
  use_dualstack       = !local.has_ipv6
  network_id          = local.use_dualstack ? data.openstack_networking_network_v2.dualstack.id : data.openstack_networking_network_v2.ipv6.id
}

resource "tls_private_key" "deployer" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  sensitive_content = tls_private_key.deployer.private_key_openssh
  filename          = local.private_key
  file_permission   = "0600"
}

data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

resource "openstack_networking_secgroup_v2" "ssh_only" {
  name        = "${local.deployment_id}-ssh"
  description = "SSH-only ingress. VNC and Ollama via SSH tunnel."
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = local.operator_cidr
  security_group_id = openstack_networking_secgroup_v2.ssh_only.id
}

resource "openstack_networking_secgroup_rule_v2" "ssh_v6" {
  count             = local.has_ipv6 ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = local.operator_ipv6_cidr
  security_group_id = openstack_networking_secgroup_v2.ssh_only.id
}

data "openstack_networking_network_v2" "ipv6" {
  name = "IPv6"
}

data "openstack_networking_network_v2" "dualstack" {
  name = "dualStack"
}

data "openstack_compute_flavor_v2" "vgpu" {
  name = var.flavor_name
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!@#%^*()-_=+"
}

resource "openstack_compute_instance_v2" "vm" {
  name              = local.deployment_id
  flavor_id         = data.openstack_compute_flavor_v2.vgpu.id
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.availability_zone
  security_groups   = [data.openstack_networking_secgroup_v2.default.name, openstack_networking_secgroup_v2.ssh_only.name]

  network {
    uuid = local.network_id
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_user       = var.admin_user
    admin_password   = random_password.admin.result
    ssh_public_key   = tls_private_key.deployer.public_key_openssh
    ollama_model     = var.ollama_model
    obsidian_deb_url = var.obsidian_deb_url
  })
}

resource "null_resource" "wait_for_cloud_init" {
  depends_on = [openstack_compute_instance_v2.vm]
  triggers = { instance_id = openstack_compute_instance_v2.vm.id }

  connection {
    type        = "ssh"
    host        = openstack_compute_instance_v2.vm.access_ip_v4
    user        = var.ssh_user
    private_key = tls_private_key.deployer.private_key_openssh
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "for i in $(seq 1 90); do",
      "  if [ -f /var/lib/cloud/instance/boot-finished ]; then echo 'cloud-init done'; exit 0; fi",
      "  sudo cloud-init status --wait --long 2>/dev/null || true",
      "  sleep 10",
      "done",
      "echo 'cloud-init did not finish within 15 min' >&2",
      "sudo cloud-init status --long >&2 || true",
      "exit 1",
    ]
  }
}
