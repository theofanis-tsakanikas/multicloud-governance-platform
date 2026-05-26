output "vpn_connection_id" {
  description = "The ID of the AWS VPN Connection"
  value       = aws_vpn_connection.aws_to_azure.id
}

output "tunnel1_address" {
  description = "The public IP of the first AWS VPN tunnel"
  value       = aws_vpn_connection.aws_to_azure.tunnel1_address
}