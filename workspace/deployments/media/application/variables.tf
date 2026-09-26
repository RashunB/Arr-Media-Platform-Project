variable "arr_host" {
  description = "IP address or hostname of the Media Platform target"
  type        = string
}

variable "prowlarr_port" {
  description = "Port for Prowlarr service"
  type        = number
  default     = 9696
}

variable "radarr_name" {
  description = "Name for Radarr instance"
  type        = string
  default     = "Radarr"
}

variable "radarr_port" {
  description = "Port for Radarr service"
  type        = number
  default     = 7878
}

variable "radarr_root_folder" {
  description = "Radarr root folder for movies"
  type        = string
  default     = "/movies"
}

variable "radarr_sync" {
  description = "Prowlarr's sync level for keeping Radarr within intended state"
  type        = string
  default     = "addOnly"
}

variable "radarr_sync_categories" {
  description = "Radarr sync categories for movies"
  type        = list(number)
  default     = [2000, 2010, 2030]
}

variable "sonarr_port" {
  description = "Port for Sonarr service"
  type        = number
  default     = 8989
}

variable "sonarr_name" {
  description = "Name of Sonarr instance"
  type        = string
  default     = "Sonarr"
}

variable "sonarr_root_folder" {
  description = "Sonarr root folder for tv series"
  type        = string
  default     = "/tv"
}

variable "sonarr_sync" {
  description = "Prowlarr's sync level for keeping Sonarr within intended state"
  type        = string
  default     = "addOnly"
}

variable "sonarr_sync_categories" {
  description = "Sonarr sync categories for tv series"
  type        = list(number)
  default     = [5000, 5010, 5030]
}

variable "sabnzbd_enabled" {
  description = "Toggle for enabling SABnzbd"
  type        = bool
  default     = true
}

variable "sabnzbd_name" {
  description = "Name of SABnzbd instance"
  type        = string
  default     = "SABnzbd"
}

variable "sabnzbd_port" {
  description = "Port for SABnzbd service"
  type        = number
  default     = 6060
}

variable "sabnzbd_prio" {
  description = "Priority level for SABnzbd as a download client"
  type        = number
  default     = 1
}
