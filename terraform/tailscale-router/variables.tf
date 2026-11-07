# --- Proxmox ---------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.2.2:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!tokenid=secret'."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (Proxmox uses a self-signed certificate by default)."
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node to create the container on (proxmoxone or proxmoxtwo)."
  type        = string
}

variable "proxmox_node_ssh_host" {
  description = "SSH address of proxmox_node. Used to run 'pct set --dev0 /dev/net/tun', which the API refuses for tokens."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox node. Must be able to run pct (root)."
  type        = string
  default     = "root"
}

# --- Container -------------------------------------------------------------

variable "vm_id" {
  description = "Container VMID."
  type        = number
  default     = 200
}

variable "hostname" {
  type    = string
  default = "tailscale-router"
}

variable "template_file_id" {
  description = "LXC template, as <storage>:vztmpl/<file>. Must exist on proxmox_node."
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "datastore" {
  description = "Datastore for the root disk."
  type        = string
  default     = "local-lvm"
}

variable "disk_gb" {
  type    = number
  default = 8
}

variable "memory_mb" {
  type    = number
  default = 512
}

variable "cpu_cores" {
  type    = number
  default = 1
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "ipv4_address" {
  description = "Static address in CIDR form. Taken: .1 gateway, .2 proxmoxone, .3 Jellyfin, .50 proxmoxtwo."
  type        = string
  default     = "192.168.2.51/24"

  validation {
    condition = !contains(
      ["192.168.2.1", "192.168.2.2", "192.168.2.3", "192.168.2.50"],
      split("/", var.ipv4_address)[0],
    )
    error_message = "That address is already in use on the lab network."
  }
}

variable "ipv4_gateway" {
  type    = string
  default = "192.168.2.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8"]
}

variable "ssh_public_keys" {
  description = "SSH public keys for root in the container (Ansible logs in with these)."
  type        = list(string)
}
