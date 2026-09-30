# application

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15 |
| <a name="requirement_prowlarr"></a> [prowlarr](#requirement\_prowlarr) | 3.2.1 |
| <a name="requirement_radarr"></a> [radarr](#requirement\_radarr) | 2.5.0 |
| <a name="requirement_sonarr"></a> [sonarr](#requirement\_sonarr) | 3.5.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | 1.4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_prowlarr"></a> [prowlarr](#provider\_prowlarr) | 3.2.1 |
| <a name="provider_radarr"></a> [radarr](#provider\_radarr) | 2.5.0 |
| <a name="provider_sonarr"></a> [sonarr](#provider\_sonarr) | 3.5.0 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.4.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [prowlarr_application_radarr.radarr](https://registry.terraform.io/providers/devopsarr/prowlarr/3.2.1/docs/resources/application_radarr) | resource |
| [prowlarr_application_sonarr.sonarr](https://registry.terraform.io/providers/devopsarr/prowlarr/3.2.1/docs/resources/application_sonarr) | resource |
| [prowlarr_host.media_platform](https://registry.terraform.io/providers/devopsarr/prowlarr/3.2.1/docs/resources/host) | resource |
| [radarr_download_client_sabnzbd.sabnzbd](https://registry.terraform.io/providers/devopsarr/radarr/2.5.0/docs/resources/download_client_sabnzbd) | resource |
| [radarr_host.media_platform](https://registry.terraform.io/providers/devopsarr/radarr/2.5.0/docs/resources/host) | resource |
| [radarr_root_folder.movies](https://registry.terraform.io/providers/devopsarr/radarr/2.5.0/docs/resources/root_folder) | resource |
| [sonarr_download_client_sabnzbd.sabnzbd](https://registry.terraform.io/providers/devopsarr/sonarr/3.5.0/docs/resources/download_client_sabnzbd) | resource |
| [sonarr_host.media_platform](https://registry.terraform.io/providers/devopsarr/sonarr/3.5.0/docs/resources/host) | resource |
| [sonarr_root_folder.tv](https://registry.terraform.io/providers/devopsarr/sonarr/3.5.0/docs/resources/root_folder) | resource |
| [sops_file.media_platform](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arr_host"></a> [arr\_host](#input\_arr\_host) | IP address or hostname of the Media Platform target | `string` | n/a | yes |
| <a name="input_prowlarr_port"></a> [prowlarr\_port](#input\_prowlarr\_port) | Port for Prowlarr service | `number` | `9696` | no |
| <a name="input_radarr_name"></a> [radarr\_name](#input\_radarr\_name) | Name for Radarr instance | `string` | `"Radarr"` | no |
| <a name="input_radarr_port"></a> [radarr\_port](#input\_radarr\_port) | Port for Radarr service | `number` | `7878` | no |
| <a name="input_radarr_root_folder"></a> [radarr\_root\_folder](#input\_radarr\_root\_folder) | Radarr root folder for movies | `string` | `"/movies"` | no |
| <a name="input_radarr_sync"></a> [radarr\_sync](#input\_radarr\_sync) | Prowlarr's sync level for keeping Radarr within intended state | `string` | `"addOnly"` | no |
| <a name="input_radarr_sync_categories"></a> [radarr\_sync\_categories](#input\_radarr\_sync\_categories) | Radarr sync categories for movies | `list(number)` | <pre>[<br/>  2000,<br/>  2010,<br/>  2030<br/>]</pre> | no |
| <a name="input_sabnzbd_enabled"></a> [sabnzbd\_enabled](#input\_sabnzbd\_enabled) | Toggle for enabling SABnzbd | `bool` | `true` | no |
| <a name="input_sabnzbd_name"></a> [sabnzbd\_name](#input\_sabnzbd\_name) | Name of SABnzbd instance | `string` | `"SABnzbd"` | no |
| <a name="input_sabnzbd_port"></a> [sabnzbd\_port](#input\_sabnzbd\_port) | Port for SABnzbd service | `number` | `6060` | no |
| <a name="input_sabnzbd_prio"></a> [sabnzbd\_prio](#input\_sabnzbd\_prio) | Priority level for SABnzbd as a download client | `number` | `1` | no |
| <a name="input_sonarr_name"></a> [sonarr\_name](#input\_sonarr\_name) | Name of Sonarr instance | `string` | `"Sonarr"` | no |
| <a name="input_sonarr_port"></a> [sonarr\_port](#input\_sonarr\_port) | Port for Sonarr service | `number` | `8989` | no |
| <a name="input_sonarr_root_folder"></a> [sonarr\_root\_folder](#input\_sonarr\_root\_folder) | Sonarr root folder for tv series | `string` | `"/tv"` | no |
| <a name="input_sonarr_sync"></a> [sonarr\_sync](#input\_sonarr\_sync) | Prowlarr's sync level for keeping Sonarr within intended state | `string` | `"addOnly"` | no |
| <a name="input_sonarr_sync_categories"></a> [sonarr\_sync\_categories](#input\_sonarr\_sync\_categories) | Sonarr sync categories for tv series | `list(number)` | <pre>[<br/>  5000,<br/>  5010,<br/>  5030<br/>]</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
