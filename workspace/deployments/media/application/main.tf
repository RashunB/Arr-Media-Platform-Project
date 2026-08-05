terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
    }
    prowlarr = {
      source = "devopsarr/prowlarr"
    }
    sonarr = {
      source = "devopsarr/sonarr"
    }
    radarr = {
      source = "devopsarr/radarr"
    }
  }
}

# Data

data "sops_file" "media_platform" {
  source_file = "/baucumlabs/secrets/media_platform.sops.yaml"
}

locals {
  url_prepend   = "http://"
  prowlarr_host = "${local.url_prepend}${var.arr_host}:${var.prowlarr_port}"
  radarr_host   = "${local.url_prepend}${var.arr_host}:${var.radarr_port}"
  sonarr_host   = "${local.url_prepend}${var.arr_host}:${var.sonarr_port}"
  sabnzbd_host  = var.arr_host
}

provider "prowlarr" {
  url     = local.prowlarr_host
  api_key = data.sops_file.media_platform.data["media_platform_prowlarr_api_key"]
}

provider "sonarr" {
  url     = local.sonarr_host
  api_key = data.sops_file.media_platform.data["media_platform_sonarr_api_key"]
}

provider "radarr" {
  url     = local.radarr_host
  api_key = data.sops_file.media_platform.data["media_platform_radarr_api_key"]
}

# Prowlarr
resource "prowlarr_host" "media_platform" {
  launch_browser  = true
  port            = var.prowlarr_port
  url_base        = ""
  bind_address    = "*"
  application_url = ""
  instance_name   = "Prowlarr"
  proxy = {
    enabled = false
  }
  ssl = {
    enabled                = false
    certificate_validation = "enabled"
  }
  logging = {
    log_level      = "info"
    log_size_limit = 1
  }
  backup = {
    folder    = "/backup"
    interval  = 5
    retention = 10
  }
  authentication = {
    username = data.sops_file.media_platform.data["media_platform_arr_webapp_username"]
    password = data.sops_file.media_platform.data["media_platform_arr_webapp_password"]
    method   = "forms"
    required = "enabled"
  }
  update = {
    mechanism = "docker"
    branch    = "develop"
  }
}

resource "prowlarr_application_sonarr" "sonarr" {
  name            = var.sonarr_name
  sync_level      = var.sonarr_sync
  base_url        = local.sonarr_host
  prowlarr_url    = local.prowlarr_host
  api_key         = data.sops_file.media_platform.data["media_platform_sonarr_api_key"]
  sync_categories = var.sonarr_sync_categories
}

resource "prowlarr_application_radarr" "radarr" {
  name            = var.radarr_name
  sync_level      = var.radarr_sync
  base_url        = local.radarr_host
  prowlarr_url    = local.prowlarr_host
  api_key         = data.sops_file.media_platform.data["media_platform_radarr_api_key"]
  sync_categories = var.radarr_sync_categories
}

# Sonarr
resource "sonarr_host" "media_platform" {
  launch_browser  = true
  port            = var.sonarr_port
  url_base        = ""
  bind_address    = "*"
  application_url = ""
  instance_name   = "Sonarr"
  proxy = {
    enabled = false
  }
  ssl = {
    enabled                = false
    certificate_validation = "enabled"
  }
  logging = {
    log_level      = "info"
    log_size_limit = 1
  }
  backup = {
    folder    = "/backup"
    interval  = 5
    retention = 10
  }
  authentication = {
    username = data.sops_file.media_platform.data["media_platform_arr_webapp_username"]
    password = data.sops_file.media_platform.data["media_platform_arr_webapp_password"]
    method   = "forms"
    required = "enabled"
  }
  update = {
    mechanism = "docker"
    branch    = "develop"
  }
}

resource "sonarr_root_folder" "tv" {
  path = var.sonarr_root_folder
}

resource "sonarr_download_client_sabnzbd" "sabnzbd" {
  name     = var.sabnzbd_name
  host     = local.sabnzbd_host
  port     = var.sabnzbd_port
  api_key  = data.sops_file.media_platform.data["media_platform_sabnzbd_api_key"]
  priority = var.sabnzbd_prio
  enable   = var.sabnzbd_enabled
}

# Radarr
resource "radarr_host" "media_platform" {
  launch_browser  = true
  port            = var.radarr_port
  url_base        = ""
  bind_address    = "*"
  application_url = ""
  instance_name   = "Radarr"
  proxy = {
    enabled = false
  }
  ssl = {
    enabled                = false
    certificate_validation = "enabled"
  }
  logging = {
    log_level      = "info"
    log_size_limit = 1
  }
  backup = {
    folder    = "/backup"
    interval  = 5
    retention = 10
  }
  authentication = {
    username = data.sops_file.media_platform.data["media_platform_arr_webapp_username"]
    password = data.sops_file.media_platform.data["media_platform_arr_webapp_password"]
    method   = "forms"
    required = "enabled"
  }
  update = {
    mechanism = "docker"
    branch    = "develop"
  }
}

resource "radarr_root_folder" "movies" {
  path = var.radarr_root_folder
}

resource "radarr_download_client_sabnzbd" "sabnzbd" {
  name     = var.sabnzbd_name
  host     = local.sabnzbd_host
  port     = var.sabnzbd_port
  api_key  = data.sops_file.media_platform.data["media_platform_sabnzbd_api_key"]
  priority = var.sabnzbd_prio
  enable   = var.sabnzbd_enabled
}