terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent    = false
    username = "root"
    password = "Par240XXX"
  }
}

locals {
  vms = {
    "web-01" = {
      vmid        = 201
      description = "Flask application + Docker"
      cores       = 2
      memory      = 2048
      disk_size   = 20
      ip          = var.web01_ip
      gw          = var.gateway
    }
    "db-01" = {
      vmid        = 202
      description = "PostgreSQL database"
      cores       = 2
      memory      = 2048
      disk_size   = 30
      ip          = var.db01_ip
      gw          = var.gateway
    }
    "monitor-01" = {
      vmid        = 203
      description = "Monitoring utilities"
      cores       = 2
      memory      = 2048
      disk_size   = 20
      ip          = var.monitor01_ip
      gw          = var.gateway
    }
  }
}

resource "proxmox_virtual_environment_file" "cloud_init_user" {
  content_type = "snippets"
  datastore_id = var.proxmox_snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    file_name = "cloud-init-user.yaml"
    data      = <<-YAML
      #cloud-config
      users:
        - name: ubuntu
          groups: sudo
          shell: /bin/bash
          sudo: ALL=(ALL) NOPASSWD:ALL
          ssh_authorized_keys:
            - ${file(var.ssh_public_key_path)}
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    YAML
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms

  name        = each.key
  vm_id       = each.value.vmid
  description = each.value.description
  node_name   = var.proxmox_node
  tags        = ["internalboard", each.key]
  on_boot     = true

  clone {
    vm_id = var.ubuntu_template_vmid
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_vm_storage
    interface    = "scsi0"
    size         = each.value.disk_size
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge   = var.proxmox_bridge
    model    = "virtio"
    firewall = false
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id      = var.proxmox_vm_storage
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user.id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.prefix_length}"
        gateway = each.value.gw
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  lifecycle {
    ignore_changes = [clone]
  }
}