output "vm_id" {
  description = "Proxmox VMID"
  value       = proxmox_virtual_environment_vm.vms[0].vm_id
}

output "primary_ip" {
  description = "First non-loopback IPv4 address"
  value       = proxmox_virtual_environment_vm.vms[0].ipv4_addresses[1][0]
}