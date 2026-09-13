# infrastructure

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 5.24.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.113.1 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | 1.4.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.24.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.113.1 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.4.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_media_vm"></a> [media\_vm](#module\_media\_vm) | ../../../modules/proxmox_vm | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.media_platform](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs/resources/dns_record) | resource |
| [proxmox_hardware_mapping_pci.transcoding_gpu](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/data-sources/hardware_mapping_pci) | data source |
| [sops_file.cloudflare](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs/data-sources/file) | data source |
| [sops_file.proxmox_id](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs/data-sources/file) | data source |
| [sops_file.public_key](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Map of disks keyed by interface name. | <pre>map(object({<br/>    datastore_id      = string<br/>    size              = optional(number, 0)<br/>    iothread          = optional(bool, true)<br/>    cache             = optional(string, "none")<br/>    discard           = optional(string, "ignore")<br/>    file_format       = optional(string, "raw")<br/>    path_in_datastore = optional(string, null)<br/>    backup            = optional(bool, false)<br/>    replicate         = optional(bool, false)<br/>    serial            = optional(string, null)<br/>  }))</pre> | n/a | yes |
| <a name="input_cloud_init_user_data_path"></a> [cloud\_init\_user\_data\_path](#input\_cloud\_init\_user\_data\_path) | Optional cloud-init #cloud-config YAML filepath. If null, a default is used. | `string` | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | n/a | `number` | `4` | no |
| <a name="input_datastore_files"></a> [datastore\_files](#input\_datastore\_files) | n/a | `string` | n/a | yes |
| <a name="input_datastore_infra"></a> [datastore\_infra](#input\_datastore\_infra) | n/a | `string` | n/a | yes |
| <a name="input_dns_comment"></a> [dns\_comment](#input\_dns\_comment) | n/a | `string` | `"Created with Terraform"` | no |
| <a name="input_dns_type"></a> [dns\_type](#input\_dns\_type) | n/a | `string` | `"A"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | n/a | `number` | `2048` | no |
| <a name="input_personal_domain"></a> [personal\_domain](#input\_personal\_domain) | n/a | `string` | n/a | yes |
| <a name="input_proxied"></a> [proxied](#input\_proxied) | n/a | `bool` | `false` | no |
| <a name="input_proxmox_api_token"></a> [proxmox\_api\_token](#input\_proxmox\_api\_token) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_node_name"></a> [proxmox\_node\_name](#input\_proxmox\_node\_name) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_user"></a> [proxmox\_user](#input\_proxmox\_user) | n/a | `string` | n/a | yes |
| <a name="input_template_os_tag"></a> [template\_os\_tag](#input\_template\_os\_tag) | os tag of the template to clone. Defaults to default (ubuntu24) from \_base. | `string` | `"default"` | no |
| <a name="input_ttl"></a> [ttl](#input\_ttl) | n/a | `number` | `1` | no |
| <a name="input_vm_count"></a> [vm\_count](#input\_vm\_count) | n/a | `number` | n/a | yes |
| <a name="input_vm_count_offset"></a> [vm\_count\_offset](#input\_vm\_count\_offset) | n/a | `number` | `1` | no |
| <a name="input_vm_default_user"></a> [vm\_default\_user](#input\_vm\_default\_user) | n/a | `string` | n/a | yes |
| <a name="input_vm_group"></a> [vm\_group](#input\_vm\_group) | n/a | `string` | n/a | yes |
| <a name="input_vm_name_prefix"></a> [vm\_name\_prefix](#input\_vm\_name\_prefix) | n/a | `string` | n/a | yes |
| <a name="input_vm_tag_list"></a> [vm\_tag\_list](#input\_vm\_tag\_list) | A set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed\_nodes | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_data_proxmox_hardware_mapping_pci"></a> [data\_proxmox\_hardware\_mapping\_pci](#output\_data\_proxmox\_hardware\_mapping\_pci) | n/a |
| <a name="output_vm"></a> [vm](#output\_vm) | n/a |
<!-- END_TF_DOCS -->
