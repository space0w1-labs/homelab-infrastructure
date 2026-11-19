resource "proxmox_virtual_environment_container" "reverse_proxy" {
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  description = "Caddy reverse proxy for *.lab names. Managed by Terraform (terraform/reverse-proxy); configured by Ansible (ansible/reverse-proxy)."
  tags        = ["terraform", "reverse-proxy"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  # Proxmox's default for unprivileged containers; Debian 12's systemd
  # needs it for some unit sandboxing. Tokens may set nesting (not keyctl).
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
    # The container is stateless (Caddyfile comes from Ansible), so
    # replacement is fine; these just aren't readable back from Proxmox.
    ignore_changes = [
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }
}
