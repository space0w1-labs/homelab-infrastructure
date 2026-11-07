output "vm_id" {
  value = proxmox_virtual_environment_container.tailscale.vm_id
}

output "ipv4_address" {
  value = split("/", var.ipv4_address)[0]
}

output "next_step" {
  value = "cd ../../ansible/tailscale-router && ansible-playbook playbook.yml --ask-vault-pass"
}
