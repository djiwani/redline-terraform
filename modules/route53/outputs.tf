output "zone_id" {
  description = "Route53 hosted zone ID — used by cloudfront module for cert validation"
  value       = aws_route53_zone.main.zone_id
}

output "nameservers" {
  description = "Add these as NS records in the parent fourallthedogs.com hosted zone to delegate this subdomain"
  value       = aws_route53_zone.main.name_servers
}
