output "endpoint_service_name" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].endpoint_service_name : ""
}

output "endpoint_service_id" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].endpoint_service_id : ""
}

output "custom_db_hostname" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].custom_db_hostname : ""
}

output "nlb_dns_name" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].nlb_dns_name : ""
}

output "ecs_cluster_name" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].ecs_cluster_name : ""
}

output "rds_proxy_endpoint" {
  value = var.is_private_connection ? module.rds_gateway["enabled"].rds_proxy_endpoint : ""
}
