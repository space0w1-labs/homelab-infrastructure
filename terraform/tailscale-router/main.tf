resource "proxmox_virtual_environment_container" "tailscale" {
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  description = "Tailscale subnet router. Managed by Terraform (terraform/tailscale-router); configured by Ansible (ansible/tailscale-router)."
  tags        = ["terraform", "tailscale"]

  unprivileged  = true
  started       = true
  start_on_boot = true

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
    swap      = 512
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
    # dev0 is added outside the provider (see below); don't let a later plan
    # try to strip it.
    ignore_changes = [device_passthrough]
  }
}

# TUN passthrough.
#
# bpg supports this natively via `device_passthrough { path = "/dev/net/tun" }`,
# which becomes `dev0: /dev/net/tun` in the container config. On Proxmox 8.1+
# that single line replaces the old pair of raw lxc.* lines
# (cgroup2.devices.allow c 10:200 + lxc.mount.entry), and works for
# unprivileged containers.
#
# But Proxmox only lets root@pam set devN entries for raw device paths, and an
# API token (even root@pam!something) fails that check. So rather than give
# Terraform the root password, it sets dev0 over SSH with pct, the same way
# you'd do it by hand, then reboots the container so the device appears.
resource "terraform_data" "tun_passthrough" {
  triggers_replace = [proxmox_virtual_environment_container.tailscale.id]

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o BatchMode=yes ${var.proxmox_ssh_username}@${var.proxmox_node_ssh_host} \
        'pct set ${var.vm_id} --dev0 /dev/net/tun && pct reboot ${var.vm_id}'
    EOT
  }
}
