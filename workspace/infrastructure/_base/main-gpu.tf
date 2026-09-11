resource "proxmox_hardware_mapping_pci" "transcoding_gpu" {
  name = "transcoding_gpu"
  map = [
    {
      comment = "GPU specific for media transcoding"
      node = "pve"
      id = "8086:56a5"
      iommu_group = 15
      path = "0000:03:00.0"
      subsystem_id = "1849:6004"
    },
  ]
}