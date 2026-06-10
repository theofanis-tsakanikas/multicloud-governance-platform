# 1. Random Password Generation
# Generates a strong, 16-character password for the database
resource "random_password" "db_pass" {
  length           = 16
  special          = true
  override_special = "!#%*-_=+"
}

# 2. Secrets Manager - Credentials Storage
# Defines the secret container in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_secret" {
  name        = "${var.password_name}-${var.environment}"
  description = "Database credentials for RDS Proxy"
  # Set to 0 to allow immediate deletion during terraform destroy
  recovery_window_in_days = 0
}

# Populates the secret with a JSON object containing the actual credentials
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username             = var.rds_username
    password             = random_password.db_pass.result
    db_engine            = var.db_engine
    rds_port             = var.rds_port
    dbInstanceIdentifier = var.db_instance_identifier
  })
}