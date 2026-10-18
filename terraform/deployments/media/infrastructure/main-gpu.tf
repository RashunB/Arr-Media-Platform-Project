data "proxmox_hardware_mapping_pci" "transcoding_gpu" {
  name = "transcoding_gpu"
}

locals {
  public_key = trimspace(file("${path.module}/../../../../secrets/ansible_id.pub"))

  pcie_map = [
    data.proxmox_hardware_mapping_pci.transcoding_gpu.name,
  ]

  pcie_devices = {
    for idx, name in local.pcie_map : "hostpci${idx}" => {
      device  = "hostpci${idx}"
      mapping = name
      pcie    = true
      rombar  = true
    }
  }
}
