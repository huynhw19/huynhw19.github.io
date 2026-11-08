POST /enterprises/$ENTERPRISE/settings/billing/budgets
{
  "budget_type": "BundlePricing",
  "budget_product_sku": "ai_credits",
  "budget_scope": "enterprise",
  "budget_amount": 50000,
  "prevent_further_usage": true,
  "budget_alerting": {
    "will_alert": true,
    "alert_recipients": ["$USERNAME"]
  }
}
