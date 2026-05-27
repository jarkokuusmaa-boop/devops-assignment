# ── Proxmox connection ────────────────────────────────────────────────────────
variable "proxmox_api_url" {
  description = "Full URL of the Proxmox API endpoint, e.g. https://192.168.1.10:8006/api2/json"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token string: <user>@<realm>!<tokenid>=<uuid>"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (true for self-signed certs in labs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Name of the Proxmox node on which to deploy VMs"
  type        = string
  default     = "pve"
}

# ── Storage / networking ──────────────────────────────────────────────────────
variable "proxmox_vm_storage" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_snippets_storage" {
  description = "Datastore that supports snippets (cloud-init files)"
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

# ── Template ──────────────────────────────────────────────────────────────────
variable "ubuntu_template_vmid" {
  description = "VMID of the Ubuntu 24.04 cloud-init template already present on Proxmox"
  type        = number
  default     = 9000
}

# ── SSH ───────────────────────────────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Path to the SSH public key that will be injected into every VM"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ── VM IPs ───────────────────────────────────────────────────────────────────
variable "web01_ip" {
  description = "Static IPv4 address for web-01"
  type        = string
  default     = "192.168.100.11"
}

variable "db01_ip" {
  description = "Static IPv4 address for db-01"
  type        = string
  default     = "192.168.100.12"
}

variable "monitor01_ip" {
  description = "Static IPv4 address for monitor-01"
  type        = string
  default     = "192.168.100.13"
}

variable "gateway" {
  description = "Default gateway for all VMs"
  type        = string
  default     = "192.168.100.1"
}

variable "prefix_length" {
  description = "Subnet prefix length (e.g. 24 → /24)"
  type        = number
  default     = 24
}

variable "dns_servers" {
  description = "DNS servers injected via cloud-init"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}
