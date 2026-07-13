# RDS Instance
resource "aws_db_instance" "sales_db" {
  identifier        = var.db_instance_identifier
  allocated_storage = var.allocated_storage
  engine            = var.db_engine
  engine_version    = var.engine_version
  instance_class    = var.db_instance_class
  db_name           = var.db_name
  username          = var.rds_username
  password          = var.password

  # Integration with outputs from the network module/file
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]

  # Logic: Determine internet reachability based on the connection type
  publicly_accessible = !var.is_private_connection
  # Set to true for easier automated cleanup (use false for Production)
  skip_final_snapshot = true

  # Checkov CKV_AWS_16. This instance holds the `crm` schema, which the domain config classifies
  # `pii` — so its storage must be encrypted at rest, full stop. Left to the AWS default this is
  # `false`, and the platform would be shipping unencrypted PII while claiming otherwise. Uses the
  # AWS-managed `aws/rds` key (no per-key cost); a production deployment can point `kms_key_id` at a
  # customer-managed key. This is enforced, not skipped: CKV_AWS_16 is off the .checkov.yml list.
  storage_encrypted = true

  # Checkov CKV2_AWS_60. A snapshot without the instance's tags is a snapshot nobody can attribute:
  # it survives the instance, it costs money, and six months later it is an orphan that no owner tag
  # points at. (This repo has already deleted one such 20 GB snapshot by hand.) One line, no cost.
  copy_tags_to_snapshot = true
}