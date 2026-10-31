# --- Proxmox ---------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.1.10:8006/"
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

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox host, used to upload the cloud-init snippet. Needs write access to the snippets directory."
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Name of the Proxmox node to create the VM on."
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the Ubuntu cloud-init template to clone."
  type        = number
}

variable "snippets_datastore" {
  description = "Datastore with the 'snippets' content type enabled."
  type        = string
  default     = "local"
}

variable "vm_datastore" {
  description = "Datastore for the VM disk and its cloud-init drive."
  type        = string
  default     = "local-lvm"
}

# --- VM --------------------------------------------------------------------

variable "vm_name" {
  description = "VM name. Also used as the hostname and, unless runner_name is set, as the runner name."
  type        = string
  default     = "github-runner"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.vm_name))
    error_message = "vm_name must be a valid hostname: lowercase letters, digits and hyphens."
  }
}

variable "vm_id" {
  description = "Fixed VM ID. Leave null to let Proxmox pick the next free one."
  type        = number
  default     = null
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "disk_gb" {
  description = "Disk size. Must be at least the template's disk size; holds the Docker cache."
  type        = number
  default     = 64
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag for the VM's network interface. Use a VLAN isolated from the rest of the LAN (see README, Security model)."
  type        = number
  default     = null
}

variable "ssh_public_keys" {
  description = "SSH public keys for the 'ubuntu' admin user."
  type        = list(string)
}

# --- GitHub runner ---------------------------------------------------------

variable "github_org" {
  description = "GitHub organization the runner registers to."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_org))
    error_message = "github_org must be a GitHub organization name."
  }
}

variable "github_pat" {
  description = "Fine-grained PAT owned by the org with only 'Self-hosted runners: read and write'."
  type        = string
  sensitive   = true
}

variable "runner_name" {
  description = "Runner name shown on GitHub. Defaults to vm_name."
  type        = string
  default     = null
}

variable "runner_group" {
  description = "Runner group to join."
  type        = string
  default     = "Default"

  validation {
    condition     = can(regex("^[A-Za-z0-9 _.-]+$", var.runner_group))
    error_message = "runner_group may only contain letters, digits, spaces, '_', '.' and '-'."
  }
}

variable "runner_labels" {
  description = "Extra labels. GitHub adds 'self-hosted', 'linux' and 'x64' automatically."
  type        = list(string)
  default     = ["homelab"]

  validation {
    condition     = alltrue([for l in var.runner_labels : can(regex("^[A-Za-z0-9_.-]+$", l))])
    error_message = "Labels may only contain letters, digits, '_', '.' and '-'."
  }
}

variable "runner_version" {
  description = "actions/runner release to install, without the leading 'v'."
  type        = string
  default     = "2.338.2"
}

variable "runner_sha256" {
  description = "SHA-256 of actions-runner-linux-x64-<runner_version>.tar.gz, from the release notes."
  type        = string
  default     = "baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40"

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.runner_sha256))
    error_message = "runner_sha256 must be a 64-character lowercase hex SHA-256."
  }
}

variable "ephemeral" {
  description = "Register again for every job. Keeps the PAT on the VM; see README, Runner modes."
  type        = bool
  default     = false
}
