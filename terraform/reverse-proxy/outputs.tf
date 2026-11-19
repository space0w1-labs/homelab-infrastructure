output "vm_id" {
  value = proxmox_virtual_environment_container.reverse_proxy.vm_id
}

output "ipv4_address" {
  value = split("/", var.ipv4_address)[0]
}

output "next_step" {
  value = "cd ../../ansible/reverse-proxy && ansible-playbook playbook.yml"
}
