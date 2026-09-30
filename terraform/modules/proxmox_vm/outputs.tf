output "vm_id" {
  description = "Proxmox VMID(s)"
  value       = proxmox_virtual_environment_vm.vms[*].vm_id
}

output "primary_ip" {
  description = "First non-loopback IPv4 address(es) of VM(s)"
  value       = proxmox_virtual_environment_vm.vms[*].ipv4_addresses[1][0]
}
