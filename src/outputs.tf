output "vpc_id" {
  value = aws_vpc.main.id
}

output "bastion_ip" {
  value = aws_instance.bastion_server.public_ip
}

output "lb_endpoint" {
  value = "https://${aws_lb.backend.dns_name}"
}