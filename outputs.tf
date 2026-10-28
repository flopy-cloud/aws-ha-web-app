output "alb_dns" {
  value = aws_lb.web.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}