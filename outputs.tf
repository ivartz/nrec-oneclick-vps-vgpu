output "deployment_id" {
  value = local.deployment_id
}

output "vm_ipv4" {
  value = openstack_compute_instance_v2.vm.access_ip_v4
}

output "vm_ipv6" {
  value = openstack_compute_instance_v2.vm.access_ip_v6
}

output "admin_user" {
  value = var.admin_user
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}

output "private_key_path" {
  value = local.private_key
}

output "vnc_password_path" {
  value = local.vnc_password_file
}

output "ssh_command" {
  value = "ssh -i ${local.private_key} ${var.ssh_user}@${openstack_compute_instance_v2.vm.access_ip_v4}"
}

output "vnc_tunnel_command" {
  value = "ssh -L ${var.local_vnc_port}:localhost:5901 -i ${local.private_key} ${var.ssh_user}@${openstack_compute_instance_v2.vm.access_ip_v4}"
}

output "ollama_tunnel_command" {
  value = "ssh -L ${var.local_ollama_port}:localhost:11434 -i ${local.private_key} ${var.ssh_user}@${openstack_compute_instance_v2.vm.access_ip_v4}"
}
