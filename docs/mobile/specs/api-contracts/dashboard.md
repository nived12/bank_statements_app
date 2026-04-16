# API Contract: Dashboard

> Updated: 2026-04-16 (Phase 2)

Base path: `/api/v1/dashboard`
Auth: JWT Bearer required

---

## GET /api/v1/dashboard

Returns all data needed to render the dashboard screen for a given month.

### Request

```
GET /api/v1/dashboard
GET /api/v1/dashboard?month=2026-04
Authorization: Bearer <access_token>
```

### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `month` | string | No | Current month | Format: `YYYY-MM` |

### Response 200

```json
{
  "data": {
    "summary": {
      "total_balance": 45000.50,
      "total_transactions": 147,
      "total_statements": 12,
      "selected_month": "2026-04"
    },
    "monthly_summary": {
      "total_income": 25000,
      "total_expenses": 12000,
      "net_income": 13000,
      "income_count": 3,
      "expense_count": 44
    },
    "monthly_stats": {
      "average_transaction": 272.73,
      "largest_expense": 5000.00,
      "largest_income": 20000.00,
      "daily_average": 400.00
    },
    "bank_accounts": [
      {
        "id": 3,
        "name": "BBVA Checking ****1234",
        "custom_name": null,
        "bank_name": "BBVA Bancomer",
        "account_type": "debit",
        "opening_balance": "0.0",
        "balance": 22000.50,
        "currency": "MXN"
      }
    ],
    "bank_summaries": [
      {
        "account_id": 3,
        "account_name": "BBVA Checking ****1234",
        "bank_name": "BBVA Bancomer",
        "balance": 22000.50,
        "transaction_count": 89,
        "recent_activity": "2026-04-15",
        "last_processed": "2026-04-14T18:00:00Z",
        "status": "processed"
      }
    ],
    "recent_transactions": [
      {
        "id": 42,
        "date": "2026-04-15",
        "description": "Uber Eats",
        "concept": "Food delivery",
        "amount": -250.50,
        "transaction_type": "variable_expense",
        "source": "statement_file",
        "merchant": "Uber Eats MX",
        "reference": null,
        "statement_file_id": 7,
        "bank_account": { "id": 3, "name": "BBVA ****1234", "account_type": "debit" },
        "category": { "id": 12, "name": "Food", "icon": "utensils" },
        "is_transfer": false,
        "transfer_account": null,
        "created_at": "2026-04-15T08:00:00Z",
        "updated_at": "2026-04-15T08:00:00Z"
      }
    ],
    "recent_statement_files": [
      {
        "id": 7,
        "filename": "bbva_abril_2026.pdf",
        "status": "processed",
        "bank_account_id": 3,
        "created_at": "2026-04-14T18:00:00Z"
      }
    ],
    "category_summary": {
      "has_data": true,
      "categories": [
        {
          "id": 12,
          "name": "Food",
          "icon": "utensils",
          "amount": 3500.00
        },
        {
          "id": null,
          "name": "Uncategorized",
          "icon": null,
          "amount": 1200.00
        }
      ]
    },
    "spending_trends": [
      {
        "month": "2026-04",
        "total_expenses": 12000,
        "total_income": 25000,
        "net_income": 13000
      }
    ],
    "available_months": [
      { "value": "2026-04", "label": "April 2026" },
      { "value": "2026-03", "label": "March 2026" }
    ]
  }
}
```

### Category Summary Notes

- `category_summary.categories` returns top 8 expense categories by amount for the selected month
- Each entry includes `id`, `name`, `icon` (Lucide icon name), and `amount` (positive float)
- `id` is `null` for uncategorized transactions
- `icon` is `null` for the uncategorized bucket
- `amount` is always positive (absolute value of expenses)
- `has_data` is `false` when there are no expense transactions for the month

### Error Response 500

```json
{
  "error": {
    "message": "Failed to load dashboard data",
    "code": "DASHBOARD_LOAD_FAILED",
    "details": []
  }
}
```
