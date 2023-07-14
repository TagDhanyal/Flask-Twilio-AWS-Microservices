output "api_gateway_endpoint" {
  value = aws_lb.app_alb.dns_name
}