# proxmox_vm

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.113.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.113.1 |
| <a name="provider_proxmox.root"></a> [proxmox.root](#provider\_proxmox.root) | 0.113.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_file.cloud_config](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.vms](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/virtual_environment_vm) | resource |
| [proxmox_virtual_environment_vms.templates](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/data-sources/virtual_environment_vms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Map of disks keyed by interface name. | <pre>map(object({<br/>    datastore_id      = string<br/>    size              = optional(number, 1)<br/>    iothread          = optional(bool, true)<br/>    cache             = optional(string, "none")<br/>    discard           = optional(string, "ignore")<br/>    file_format       = optional(string, "raw")<br/>    path_in_datastore = optional(string, null)<br/>    backup            = optional(bool, false)<br/>    replicate         = optional(bool, false)<br/>    serial            = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_cloud_init_user_data_path"></a> [cloud\_init\_user\_data\_path](#input\_cloud\_init\_user\_data\_path) | Path to cloun-init .tpl file. If null, the module default is used. | `string` | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | n/a | `number` | `2` | no |
| <a name="input_datastore_files"></a> [datastore\_files](#input\_datastore\_files) | n/a | `string` | `"vmfiles"` | no |
| <a name="input_datastore_infra"></a> [datastore\_infra](#input\_datastore\_infra) | n/a | `string` | `"vmdata"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | n/a | `number` | `2048` | no |
| <a name="input_pcie_devices"></a> [pcie\_devices](#input\_pcie\_devices) | n/a | <pre>map(object({<br/>    device  = optional(string, null)<br/>    mapping = optional(string, null)<br/>    pcie    = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| <a name="input_personal_domain"></a> [personal\_domain](#input\_personal\_domain) | n/a | `string` | `"home.lab"` | no |
| <a name="input_proxmox_node_name"></a> [proxmox\_node\_name](#input\_proxmox\_node\_name) | n/a | `string` | n/a | yes |
| <a name="input_ssh_public_key_path"></a> [ssh\_public\_key\_path](#input\_ssh\_public\_key\_path) | n/a | `string` | `"/baucumlabs/secrets/ansible_id.pub"` | no |
| <a name="input_template_os_tag"></a> [template\_os\_tag](#input\_template\_os\_tag) | os tag of the template to clone. Defaults to default (ubuntu24) from \_base. | `string` | `"default"` | no |
| <a name="input_vm_count"></a> [vm\_count](#input\_vm\_count) | n/a | `number` | `1` | no |
| <a name="input_vm_count_offset"></a> [vm\_count\_offset](#input\_vm\_count\_offset) | n/a | `number` | `1` | no |
| <a name="input_vm_default_tag_list"></a> [vm\_default\_tag\_list](#input\_vm\_default\_tag\_list) | Default set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed\_nodes | `list(string)` | <pre>[<br/>  "terraform"<br/>]</pre> | no |
| <a name="input_vm_default_user"></a> [vm\_default\_user](#input\_vm\_default\_user) | n/a | `string` | n/a | yes |
| <a name="input_vm_group"></a> [vm\_group](#input\_vm\_group) | n/a | `string` | n/a | yes |
| <a name="input_vm_name_prefix"></a> [vm\_name\_prefix](#input\_vm\_name\_prefix) | n/a | `string` | n/a | yes |
| <a name="input_vm_tag_list"></a> [vm\_tag\_list](#input\_vm\_tag\_list) | A set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed\_nodes | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_primary_ip"></a> [primary\_ip](#output\_primary\_ip) | First non-loopback IPv4 address |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | Proxmox VMID |
<!-- END_TF_DOCS -->
