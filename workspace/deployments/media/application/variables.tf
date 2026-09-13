variable "arr_host" {
  type = string
}

variable "prowlarr_port" {
  type    = number
  default = 9696
}

variable "radarr_name" {
  type    = string
  default = "Radarr"
}

variable "radarr_port" {
  type    = number
  default = 7878
}

variable "radarr_root_folder" {
  type    = string
  default = "/movies"
}

variable "radarr_sync" {
  type    = string
  default = "addOnly"
}

variable "radarr_sync_categories" {
  type    = list(number)
  default = [2000, 2010, 2030]
}

variable "sonarr_port" {
  type    = number
  default = 8989
}

variable "sonarr_name" {
  type    = string
  default = "Sonarr"
}

variable "sonarr_root_folder" {
  type    = string
  default = "/tv"
}

variable "sonarr_sync" {
  type    = string
  default = "addOnly"
}

variable "sonarr_sync_categories" {
  type    = list(number)
  default = [5000, 5010, 5030]
}

variable "sabnzbd_enabled" {
  type    = bool
  default = true
}

variable "sabnzbd_name" {
  type    = string
  default = "SABnzbd"
}

variable "sabnzbd_port" {
  type    = number
  default = 6060
}

variable "sabnzbd_prio" {
  type    = number
  default = 1
}

# variable "indexer" {
#   type = object({
#     name            = string
#     implementation  = string
#     config_contract = string
#     protocol        = string
#     enabled         = bool
#     redirect        = bool
#     base_url        = string
#     api_path        = string
#     tags            = optional(string, null)
#   })
# }
