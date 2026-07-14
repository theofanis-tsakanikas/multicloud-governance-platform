terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake", version = "~> 2.0"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}
