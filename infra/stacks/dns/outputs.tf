output "zone_id" {
  value = aws_route53_zone.primary.zone_id
}

output "name_servers" {
  value = aws_route53_zone.primary.name_servers
}

output "namecheap_instructions" {
  value = "Set the Namecheap custom DNS nameservers for chrisuehlinger.com to the values in the name_servers output."
}
