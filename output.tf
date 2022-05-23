
output "service_discovery_arn" {
  value = aws_service_discovery_service.service_discovery.arn
}

output "ALB_URL" {
  value =aws_lb.this.dns_name
}


output "domain_name" {
  value = aws_route53_record.this.fqdn
}

