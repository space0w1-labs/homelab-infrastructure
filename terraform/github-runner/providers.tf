provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Snippets can't be uploaded through the Proxmox API, so the provider
  # copies them over SSH. Keys are taken from your running ssh-agent.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username

    # Use the endpoint's host rather than letting the provider pick an
    # address from the node's network interfaces.
    node {
      name    = var.proxmox_node
      address = regex("^https?://([^:/]+)", var.proxmox_endpoint)[0]
    }
  }
}
