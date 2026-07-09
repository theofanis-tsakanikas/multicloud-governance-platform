variable "domain" {
  description = "Domain name (for the warehouse comment)."
  type        = string
}

variable "warehouse_name" {
  description = "Name of the domain warehouse."
  type        = string
}

variable "resource_monitor_name" {
  description = "Name of the resource monitor capping the warehouse's credit usage."
  type        = string
}

variable "warehouse_size" {
  description = "Warehouse size (e.g. XSMALL, SMALL)."
  type        = string
  default     = "XSMALL"
}

variable "auto_suspend" {
  description = "Seconds of inactivity before the warehouse auto-suspends."
  type        = number
  default     = 60
}

variable "credit_quota" {
  description = "Monthly credit quota for the resource monitor."
  type        = number
  default     = 100
}

variable "frequency" {
  description = "Resource monitor reset frequency."
  type        = string
  default     = "MONTHLY"
}

variable "start_timestamp" {
  description = "Resource monitor start timestamp."
  type        = string
  default     = "2026-01-01 00:00"
}

variable "notify_triggers" {
  description = "Percent-of-quota thresholds that notify (no action)."
  type        = list(number)
  default     = [80, 90]
}

variable "suspend_trigger" {
  description = "Percent-of-quota at which the warehouse suspends (letting running queries finish)."
  type        = number
  default     = 100
}

variable "suspend_immediate_trigger" {
  description = "Percent-of-quota at which the warehouse suspends immediately (killing queries)."
  type        = number
  default     = 110
}
