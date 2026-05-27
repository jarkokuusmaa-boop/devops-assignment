output "vm_ip_addresses" {
  description = "IP addresses of all provisioned VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm :
    name => local.vms[name].ip
  }
}

output "web01_ip" {
  description = "IP address of web-01"
  value       = var.web01_ip
}

output "db01_ip" {
  description = "IP address of db-01"
  value       = var.db01_ip
}

output "monitor01_ip" {
  description = "IP address of monitor-01"
  value       = var.monitor01_ip
}

output "app_url" {
  description = "URL to access the Flask application"
  value       = "http://${var.web01_ip}:5000"
}
