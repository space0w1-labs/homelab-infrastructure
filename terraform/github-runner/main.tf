locals {
  runner_name = coalesce(var.runner_name, var.vm_name)

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname        = var.vm_name
    ssh_public_keys = var.ssh_public_keys
    github_org      = var.github_org
    github_pat      = var.github_pat
    runner_name     = local.runner_name
    runner_group    = var.runner_group
    runner_labels   = join(",", var.runner_labels)
    runner_version  = var.runner_version
    runner_sha256   = var.runner_sha256
    ephemeral       = var.ephemeral

    token_script     = file("${path.module}/scripts/github-runner-token")
    setup_script     = file("${path.module}/scripts/github-runner-setup")
    ephemeral_script = file("${path.module}/scripts/github-runner-ephemeral")
    ephemeral_unit   = file("${path.module}/scripts/github-runner-ephemeral.service")
  })
}

# Rendered user-data, uploaded over SSH to the Proxmox host's snippets
# directory. Contains the PAT, so it is also stored in Terraform state.
resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.proxmox_node

  source_raw {
    data      = local.user_data
    file_name = "${var.vm_name}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "runner" {
  name        = var.vm_name
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  description = "GitHub Actions runner for the ${var.github_org} org. Managed by Terraform (terraform/github-runner)."
  tags        = ["terraform", "github-runner"]

  started = true
  on_boot = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  # Terraform waits for the agent to report an IP. cloud-init installs it on
  # first boot, so the first apply sits at "still creating" for a few minutes.
  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.disk_gb
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  lifecycle {
    # cloud-init only runs on first boot, so a changed user-data needs a new VM.
    replace_triggered_by = [proxmox_virtual_environment_file.user_data]
  }
}
