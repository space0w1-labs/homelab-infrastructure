resource "proxmox_virtual_environment_container" "jenkins" {
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  description = "Jenkins controller (builds and pushes images to the k3s registry). Managed by Terraform (terraform/jenkins); configured by Ansible (ansible/jenkins)."
  tags        = ["terraform", "jenkins"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  # Docker runs inside the container, which needs nesting (set here) and
  # keyctl (set over SSH below).
  features {
    nesting = true
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  lifecycle {
    # JENKINS_HOME lives on the root disk, so replacing the container loses
    # every job, credential and build. Fail the plan instead.
    prevent_destroy = true

    ignore_changes = [
      # keyctl is added outside the provider (see below).
      features,
      # Not readable back from Proxmox, so an imported container would
      # otherwise plan a replacement.
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }
}

# keyctl feature flag.
#
# Proxmox only lets root@pam change feature flags other than nesting, and an
# API token (even root@pam!something) fails that check. Same workaround as
# terraform/tailscale-router: set it over SSH with pct. The reboot only
# happens when the flag was missing, so importing the existing container
# doesn't restart Jenkins.
resource "terraform_data" "keyctl" {
  triggers_replace = [proxmox_virtual_environment_container.jenkins.id]

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o BatchMode=yes ${var.proxmox_ssh_username}@${var.proxmox_node_ssh_host} \
        'pct config ${var.vm_id} | grep -q "keyctl=1" || { pct set ${var.vm_id} --features nesting=1,keyctl=1 && pct reboot ${var.vm_id}; }'
    EOT
  }
}
