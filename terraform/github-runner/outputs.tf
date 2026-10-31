output "vm_id" {
  value = proxmox_virtual_environment_vm.runner.vm_id
}

output "ipv4_addresses" {
  description = "VM IPv4 addresses reported by the guest agent (loopback excluded)."
  value = [
    for ip in flatten(proxmox_virtual_environment_vm.runner.ipv4_addresses) : ip
    if ip != "127.0.0.1"
  ]
}

output "runner_name" {
  value = local.runner_name
}

output "runners_page" {
  value = "https://github.com/organizations/${var.github_org}/settings/actions/runners"
}
