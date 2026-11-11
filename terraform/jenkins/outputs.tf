output "vm_id" {
  value = proxmox_virtual_environment_container.jenkins.vm_id
}

output "ipv4_address" {
  value = split("/", var.ipv4_address)[0]
}

output "jenkins_url" {
  value = "http://${split("/", var.ipv4_address)[0]}:8080/"
}

output "next_step" {
  value = "cd ../../ansible/jenkins && ansible-playbook playbook.yml"
}
