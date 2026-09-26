resource "cloudflare_dns_record" "media_platform" {
  zone_id = var.cloudflare_zone_id
  name    = "www.media.baucummail.com"
  content = module.media_vm.primary_ip[0]
  type    = var.cloudflare_dns_type
  ttl     = var.cloudflare_ttl
  proxied = var.cloudflare_proxied
  comment = var.cloudflare_dns_comment
}
