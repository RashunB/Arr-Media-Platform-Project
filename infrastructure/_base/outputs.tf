output "ubuntu24_template_id" {
  value       = proxmox_virtual_environment_vm.ubuntu24_template.vm_id
  description = "VM ID of the Ubuntu 24 template, used by deployments"
}

output "rocky9_template_id" {
  value       = proxmox_virtual_environment_vm.rocky9_template.vm_id
  description = "VM ID of the Rocky 9 template, used by deployments"
}