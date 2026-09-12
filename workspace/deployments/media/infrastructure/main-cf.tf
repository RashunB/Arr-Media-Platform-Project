resource "cloudflare_dns_record" "media_platform" {
  zone_id = data.sops_file.cloudflare.data["cloudflare_zone_id"]
  name = "www.media.baucummail.com"
  content = module.media_vm.primary_ip
  type = var.dns_type
  ttl = var.ttl
  proxied = var.proxied
  comment = var.dns_comment
}
