resource "oci_budget_budget" "cost_guard" {
  count = var.budget_alert_email != "" ? 1 : 0

  compartment_id = var.tenancy_ocid
  targets        = [local.compartment_id]
  target_type    = "COMPARTMENT"
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  display_name   = "${var.instance_name}-cost-guard"
  description    = "Tripwire: everything here should stay inside Always Free, so any spend at all is a signal."
}

resource "oci_budget_alert_rule" "cost_guard" {
  count = var.budget_alert_email != "" ? 1 : 0

  budget_id      = oci_budget_budget.cost_guard[0].id
  display_name   = "${var.instance_name}-cost-guard-actual"
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud registered real spend. Something left the Always Free tier."
}

# Warns before the money is spent: fires when Oracle forecasts the month
# will end above the budget, not only after the spend has happened.
resource "oci_budget_alert_rule" "cost_guard_forecast" {
  count = var.budget_alert_email != "" ? 1 : 0

  budget_id      = oci_budget_budget.cost_guard[0].id
  display_name   = "${var.instance_name}-cost-guard-forecast"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "Oracle Cloud forecasts spend above the budget this month. Something is leaving the Always Free tier."
}
