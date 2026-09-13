terraform {
  required_version = ">= 1.15"
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "3.2.1"
    }
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.4.2"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.4.0"
    }
  }
}
