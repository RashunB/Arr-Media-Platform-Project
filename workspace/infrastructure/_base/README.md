# _base

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.9.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.113.1 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | 1.4.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.113.1 |
| <a name="provider_proxmox.root"></a> [proxmox.root](#provider\_proxmox.root) | 0.113.1 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.4.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.rocky9](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/download_file) | resource |
| [proxmox_download_file.ubuntu24](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/download_file) | resource |
| [proxmox_hardware_mapping_pci.transcoding_gpu](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/hardware_mapping_pci) | resource |
| [proxmox_virtual_environment_vm.rocky9_template](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/virtual_environment_vm) | resource |
| [proxmox_virtual_environment_vm.ubuntu24_template](https://registry.terraform.io/providers/bpg/proxmox/0.113.1/docs/resources/virtual_environment_vm) | resource |
| [sops_file.proxmox_id](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_datastore_files"></a> [datastore\_files](#input\_datastore\_files) | n/a | `string` | n/a | yes |
| <a name="input_datastore_infra"></a> [datastore\_infra](#input\_datastore\_infra) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_api_token"></a> [proxmox\_api\_token](#input\_proxmox\_api\_token) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_endpoint"></a> [proxmox\_endpoint](#input\_proxmox\_endpoint) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_node_name"></a> [proxmox\_node\_name](#input\_proxmox\_node\_name) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | n/a | `string` | n/a | yes |
| <a name="input_proxmox_user"></a> [proxmox\_user](#input\_proxmox\_user) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_rocky9_template_id"></a> [rocky9\_template\_id](#output\_rocky9\_template\_id) | VM ID of the Rocky 9 template, used by deployments |
| <a name="output_transcoding_gpu"></a> [transcoding\_gpu](#output\_transcoding\_gpu) | n/a |
| <a name="output_ubuntu24_template_id"></a> [ubuntu24\_template\_id](#output\_ubuntu24\_template\_id) | VM ID of the Ubuntu 24 template, used by deployments |
<!-- END_TF_DOCS -->
