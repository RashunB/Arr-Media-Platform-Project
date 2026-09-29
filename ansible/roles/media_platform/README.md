# media_platform

Deploys the media stack as a single Docker Compose project: Jellyfin with
Intel GPU transcoding, Sonarr, Radarr, Prowlarr, SABnzbd, Bazarr, Seerr, and
Configarr. `media_platform.yml` applies it to the `media_platform` group
after `docker_base` and `lvm_storage`, and the Terraform
`deployments/media/application` stack configures the running services
afterwards.

## What it does

The task files run in this order (`tasks/main.yml`):

1. `users.yml` creates the service user and group
   (`media_platform_user` / `media_platform_group`, UID/GID 6000) that every
   container runs as through `PUID`/`PGID`.
2. `media_directories.yml` creates one shared data tree under
   `media_platform_data_dir` (library, downloads, incomplete downloads) and a
   `/config` directory per service. A single tree lets the \*arr apps
   hardlink and move files atomically instead of copying.
3. `sabnzbd.yml`, `configarr.yml`, and `bazarr.yml` render each service's
   configuration before first start, so services come up already configured.
   Configarr syncs quality profiles and custom formats from TRaSH Guides
   templates into Sonarr and Radarr.
4. `gpu.yml` installs the kernel extra modules, Intel media driver, and
   `vainfo`, adds the service user to `video` and `render`, and reboots
   through a flushed handler when the kernel modules change.
5. `compose.yml` renders `docker-compose.yml` and `media_platform.env` into
   `media_platform_compose_dir` and starts the project.

Every task that renders a credential sets `no_log: true`.

## Requirements

- `docker_base` and `lvm_storage` applied first (the playbook does both).
- The VM-level GPU passthrough from the Terraform media stack; see
  [GPU passthrough](../../../docs/knowledge-base/gpu-passthrough.md).
- Secrets in `secrets/media_platform.sops.yaml`, loaded through the
  `group_vars/media_platform.sops.yml` symlink.

## Services

| Service | Default image | Default host port | Purpose |
|---|---|---|---|
| jellyfin | `lscr.io/linuxserver/jellyfin:latest` | 8096 | Media server; VA-API transcoding through `/dev/dri/renderD128` |
| sonarr | `lscr.io/linuxserver/sonarr:latest` | 8989 | TV series management |
| radarr | `lscr.io/linuxserver/radarr:latest` | 7878 | Movie management |
| prowlarr | `lscr.io/linuxserver/prowlarr:latest` | 9696 | Indexer management, synced to Sonarr and Radarr |
| sabnzbd | `lscr.io/linuxserver/sabnzbd:latest` | 8080 (6060 in `group_vars/media_platform`) | Usenet downloader |
| bazarr | `lscr.io/linuxserver/bazarr:latest` | 6767 | Subtitles |
| seerr | `ghcr.io/seerr-team/seerr:latest` | 5055 | Request portal |
| configarr | `docker.io/configarr/configarr:latest` | none | One-shot sync of quality profiles and custom formats |

Each service has `media_platform_<service>_name`, `_image`, and `_host_port`
variables (Configarr has no port), plus `_api_key` where the service exposes
an API.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `media_platform_user` | str | `media` | System user owning media data and running the containers (PUID). |
| `media_platform_user_uid` | int | `6000` | UID of the media service user. |
| `media_platform_group` | str | `media_platform` | System group owning media data (PGID). |
| `media_platform_group_gid` | int | `6000` | GID of the media service group. |
| `media_platform_arr_webapp_username` | str | from `media_platform.sops.yaml` | Admin username applied to the \*arr web UIs. |
| `media_platform_arr_webapp_password` | str | from `media_platform.sops.yaml` | Admin password applied to the \*arr web UIs. |
| `media_platform_usenet_provider` | str | `news.newshosting.com` | Usenet provider hostname used by SABnzbd. |
| `media_platform_usenet_user` | list of str | from `media_platform.sops.yaml` | Usenet provider user. |
| `media_platform_usenet_password` | list of str | from `media_platform.sops.yaml` | Usenet provider user password. |
| `media_platform_compose_dir` | str | `/opt/docker/media_platform` | Directory holding the compose project and rendered env file. |
| `media_platform_root_dir` | str | `/opt/media_platform` | Base directory for all media data and config. |
| `media_platform_data_dir` | str | `{{ media_platform_root_dir }}/data` | Root of the single shared data tree enabling hardlinks and atomic moves. |
| `media_platform_config_dir` | str | `{{ media_platform_root_dir }}/config` | Parent directory for per-service /config volumes. |
| `media_platform_media_dir` | str | `{{ media_platform_data_dir }}/media` | Library root for organized media. |
| `media_platform_tvseries_dir` | str | `{{ media_platform_media_dir }}/tv` | TV series library path. |
| `media_platform_movies_dir` | str | `{{ media_platform_media_dir }}/movies` | Movie library path. |
| `media_platform_downloads_dir` | str | `{{ media_platform_data_dir }}/downloads` | Completed downloads path. |
| `media_platform_incomplete_downloads_dir` | str | `{{ media_platform_data_dir }}/incomplete_downloads` | In-progress downloads path. |
| `media_platform_dir_list` | list of str | see `defaults/main.yml` | Directories created during provisioning. |
| `media_platform_services_list` | list of str | see `defaults/main.yml` | Services provisioned with a dedicated /config directory. |
| `media_platform_compose_env_list` | list of str | none | List of compose files to create from templates. |
| `media_platform_opensubtitles_user` | list of str | from `media_platform.sops.yaml` | Opensubtitles provider user. |
| `media_platform_opensubtitles_password` | list of str | from `media_platform.sops.yaml` | Opensubtitles provider user password. |

Per-service variables:

| Variable | Type | Default | Description |
|---|---|---|---|
| `media_platform_jellyfin_name` | str | `jellyfin` | Container/service name for Jellyfin. |
| `media_platform_jellyfin_hostname` | str | `{{ media_platform_jellyfin_name }}` | Hostname assigned to the Jellyfin container. |
| `media_platform_jellyfin_image` | str | `lscr.io/linuxserver/jellyfin:latest` | Container image reference for Jellyfin. |
| `media_platform_jellyfin_host_port` | int | `8096` | Host port published for Jellyfin. |
| `media_platform_jellyfin_api_key` | list of str | from `media_platform.sops.yaml` | Jellyfin API key. |
| `media_platform_seerr_name` | str | `seerr` | Container/service name for Seerr. |
| `media_platform_seerr_image` | str | `ghcr.io/seerr-team/seerr:latest` | Container image reference for Seerr. |
| `media_platform_seerr_host_port` | int | `5055` | Host port published for Seerr. |
| `media_platform_prowlarr_name` | str | `prowlarr` | Container/service name for Prowlarr. |
| `media_platform_prowlarr_image` | str | `lscr.io/linuxserver/prowlarr:latest` | Container image reference for Prowlarr. |
| `media_platform_prowlarr_host_port` | int | `9696` | Host port published for Prowlarr. |
| `media_platform_prowlarr_api_key` | str | from `media_platform.sops.yaml` | API key applied to Prowlarr. |
| `media_platform_sabnzbd_name` | str | `sabnzbd` | Container/service name for SABnzbd. |
| `media_platform_sabnzbd_image` | str | `lscr.io/linuxserver/sabnzbd:latest` | Container image reference for SABnzbd. |
| `media_platform_sabnzbd_host_port` | int | `8080` | Host port published for SABnzbd. |
| `media_platform_sabnzbd_api_key` | str | from `media_platform.sops.yaml` | API key applied to SABnzbd. |
| `media_platform_sabnzbd_nzb_key` | str | from `media_platform.sops.yaml` | NZB key applied to SABnzbd. |
| `media_platform_radarr_name` | str | `radarr` | Container/service name for Radarr. |
| `media_platform_radarr_image` | str | `lscr.io/linuxserver/radarr:latest` | Container image reference for Radarr. |
| `media_platform_radarr_host_port` | int | `7878` | Host port published for Radarr. |
| `media_platform_radarr_api_key` | str | from `media_platform.sops.yaml` | API key applied to Radarr. |
| `media_platform_sonarr_name` | str | `sonarr` | Container/service name for Sonarr. |
| `media_platform_sonarr_image` | str | `lscr.io/linuxserver/sonarr:latest` | Container image reference for Sonarr. |
| `media_platform_sonarr_host_port` | int | `8989` | Host port published for Sonarr. |
| `media_platform_sonarr_api_key` | str | from `media_platform.sops.yaml` | API key applied to Sonarr. |
| `media_platform_bazarr_name` | str | `bazarr` | Container/service name for Bazarr. |
| `media_platform_bazarr_image` | str | `lscr.io/linuxserver/bazarr:latest` | Container image reference for Bazarr. |
| `media_platform_bazarr_host_port` | int | `6767` | Host port published for Bazarr. |
| `media_platform_bazarr_api_key` | list of str | from `media_platform.sops.yaml` | Bazarr API key. |
| `media_platform_bazarr_flask_secret_key` | list of str | from `media_platform.sops.yaml` | Bazarr flask API key. |
| `media_platform_configarr_name` | str | `configarr` | Container/service name for Configarr. |
| `media_platform_configarr_image` | str | `docker.io/configarr/configarr:latest` | Container image reference for Configarr. |

## Example

```yaml
- name: Media Platform
  hosts: media_platform
  become: true
  force_handlers: true
  tasks:
    - ansible.builtin.import_role:
        name: docker_base
    - ansible.builtin.import_role:
        name: lvm_storage
    - ansible.builtin.import_role:
        name: media_platform
```
