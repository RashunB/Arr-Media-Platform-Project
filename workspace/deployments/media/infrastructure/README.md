# infrastructure

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 5.24.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.113.1 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | 1.4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.24.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.113.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_media_vm"></a> [media\_vm](#module\_media\_vm) | ../../../modules/proxmox_vm | n/a |

## Resources

| Name | Type |
|------|------|
| [cloudflare_dns_record.media_platform](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs/resources/dns_record) | resource |
| [proxmox_hardware_mapping_pci.transcoding_gpu](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/data-sources/hardware_mapping_pci) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_disks"></a> [additional\_disks](#input\_additional\_disks) | Map of disks keyed by interface name. | <pre>map(object({<br/>    datastore_id      = string<br/>    size              = optional(number, 1)<br/>    iothread          = optional(bool, true)<br/>    cache             = optional(string, "none")<br/>    discard           = optional(string, "ignore")<br/>    file_format       = optional(string, "raw")<br/>    path_in_datastore = optional(string, null)<br/>    backup            = optional(bool, false)<br/>    replicate         = optional(bool, false)<br/>    serial            = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_cloud_init_user_data_path"></a> [cloud\_init\_user\_data\_path](#input\_cloud\_init\_user\_data\_path) | Path to cloud-init .tpl file. If null, the module default is used. | `string` | `null` | no |
| <a name="input_cloudflare_dns_comment"></a> [cloudflare\_dns\_comment](#input\_cloudflare\_dns\_comment) | Cloudflare DNS comment for the DNS record created | `string` | `"Created with Terraform"` | no |
| <a name="input_cloudflare_dns_type"></a> [cloudflare\_dns\_type](#input\_cloudflare\_dns\_type) | Cloudflare DNS type, pertains to the record to create: A, CNAME, AAAA, MX, etc. | `string` | `"A"` | no |
| <a name="input_cloudflare_proxied"></a> [cloudflare\_proxied](#input\_cloudflare\_proxied) | Cloudflare toggle to proxy a DNS record. Defaults to false for local addresses | `bool` | `false` | no |
| <a name="input_cloudflare_ttl"></a> [cloudflare\_ttl](#input\_cloudflare\_ttl) | Cloudflare Time-to-Live in seconds | `number` | `600` | no |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare Zone ID | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Number of CPUs | `number` | `2` | no |
| <a name="input_datastore_files"></a> [datastore\_files](#input\_datastore\_files) | Proxmox datastore to store file components provisioned by Terraform | `string` | n/a | yes |
| <a name="input_datastore_infra"></a> [datastore\_infra](#input\_datastore\_infra) | Proxmox datastore to store infrastructure components provisioned by Terraform | `string` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | List of DNS servers written to VMs cloud-init network config | `list(string)` | <pre>[<br/>  "192.168.0.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Total amount of memory in MBs | `number` | `2048` | no |
| <a name="input_personal_domain"></a> [personal\_domain](#input\_personal\_domain) | Personal domain to use for VM hostname | `string` | `"home.lab"` | no |
| <a name="input_proxmox_api_token"></a> [proxmox\_api\_token](#input\_proxmox\_api\_token) | Proxmox host API token for routine connectivity | `string` | n/a | yes |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | Endpoint for the proxmox host in format of 'https://hostname:port/' | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS certificate verification for Proxmox API | `bool` | `true` | no |
| <a name="input_proxmox_node_name"></a> [proxmox\_node\_name](#input\_proxmox\_node\_name) | Proxmox host node name | `string` | n/a | yes |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | Password for proxmox user defined for escalated, privileged actions | `string` | n/a | yes |
| <a name="input_proxmox_user"></a> [proxmox\_user](#input\_proxmox\_user) | Proxmox user for escalated, privileged actions | `string` | n/a | yes |
| <a name="input_template_os_tag"></a> [template\_os\_tag](#input\_template\_os\_tag) | os tag of the template to clone. Defaults to default (ubuntu24) from \_base. | `string` | `"default"` | no |
| <a name="input_vm_count"></a> [vm\_count](#input\_vm\_count) | Counf for VMs to create. Defaults to one | `number` | `1` | no |
| <a name="input_vm_count_offset"></a> [vm\_count\_offset](#input\_vm\_count\_offset) | VM count offset. Used for deploying vms with the same name, but different configurations. This offsets the count to keep it consecutive across two deployments | `number` | `1` | no |
| <a name="input_vm_default_user"></a> [vm\_default\_user](#input\_vm\_default\_user) | Default user for VM setup and configuration | `string` | n/a | yes |
| <a name="input_vm_group"></a> [vm\_group](#input\_vm\_group) | Group to initially put the VM in | `string` | n/a | yes |
| <a name="input_vm_name_prefix"></a> [vm\_name\_prefix](#input\_vm\_name\_prefix) | Prefix for the VM name | `string` | n/a | yes |
| <a name="input_vm_tag_list"></a> [vm\_tag\_list](#input\_vm\_tag\_list) | A set of tags used for organizing and grouping for ansible inventory. Terraform tag is used as default tag to signal managed\_nodes | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_proxmox_hardware_mapping_pci"></a> [data\_proxmox\_hardware\_mapping\_pci](#output\_data\_proxmox\_hardware\_mapping\_pci) | PCIE device output of attached Transcoding GPU |
| <a name="output_vm"></a> [vm](#output\_vm) | VMs created, displays IP addresses and VMIDs in two lists |
<!-- END_TF_DOCS -->
