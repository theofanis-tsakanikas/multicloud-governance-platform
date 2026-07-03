# Cost governance — a domain warehouse bound to a resource monitor.
#
# Governance is not only access: a runaway warehouse is a governance failure too. Each
# domain gets a right-sized, auto-suspending warehouse whose credit consumption is capped
# by a resource monitor (suspend at quota) — the enforcement counterpart of the platform's
# offline cost/carbon estimate (scripts/cost_estimate.py, which now prices Snowflake credits).

resource "snowflake_resource_monitor" "domain" {
  name         = var.resource_monitor_name
  credit_quota = var.credit_quota

  frequency       = var.frequency
  start_timestamp = var.start_timestamp

  notify_triggers           = var.notify_triggers
  suspend_trigger           = var.suspend_trigger
  suspend_immediate_trigger = var.suspend_immediate_trigger
}

resource "snowflake_warehouse" "domain" {
  name                = var.warehouse_name
  warehouse_size      = var.warehouse_size
  auto_suspend        = var.auto_suspend
  auto_resume         = "true"
  initially_suspended = "true"
  resource_monitor    = snowflake_resource_monitor.domain.name
  comment             = "Domain warehouse for '${var.domain}' with capped credit consumption."
}
