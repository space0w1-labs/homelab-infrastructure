provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Snippets can't be uploaded through the Proxmox API, so the provider
  # copies them over SSH. Keys are taken from your running ssh-agent.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
