output "vm" {
  description = "VMs created, displays IP addresses and VMIDs in two lists"
  value       = module.media_vm
}

output "data_proxmox_hardware_mapping_pci" {
  description = "PCIE device output of attached Transcoding GPU"
  value       = data.proxmox_hardware_mapping_pci.transcoding_gpu
}
