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
