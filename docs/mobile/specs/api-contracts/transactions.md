# API Contract: Transactions

> Updated: 2026-04-16 (Phase 2)

Base path: `/api/v1/transactions`
Auth: JWT Bearer required on all endpoints

---

## GET /api/v1/transactions

List transactions with filtering, sorting, and pagination.

### Request

```
GET /api/v1/transactions
Authorization: Bearer <access_token>
```

### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `bank_account_id` | integer | No | — | Filter by bank account |
| `statement_file_id` | integer | No | — | Filter by source statement file |
| `category_id` | integer | No | — | Filter by category (includes subcategories) |
| `transaction_type` | string | No | — | One of: `income`, `fixed_expense`, `variable_expense`, `transfer_in`, `transfer_out`, `transfer` |
| `from_date` | date | No | — | Filter from date (inclusive), format: `YYYY-MM-DD` |
| `to_date` | date | No | — | Filter to date (inclusive), format: `YYYY-MM-DD` |
| `search` | string | No | — | Search in description |
| `sort` | string | No | `date` | Sort field: `date`, `amount`, `description` |
| `direction` | string | No | `desc` | Sort direction: `asc` or `desc` |
| `page` | integer | No | `1` | Page number |
| `page_size` | integer | No | `20` | Items per page (max: 100) |

### Response 200

```json
{
  "data": {
    "transactions": [
      {
        "id": 42,
        "date": "2026-04-15",
        "description": "Uber Eats",
        "concept": "Food delivery - tacos",
        "amount": -250.50,
        "transaction_type": "variable_expense",
        "source": "statement_file",
        "merchant": "Uber Eats MX",
        "reference": "UE-20260415-001",
        "statement_file_id": 7,
        "bank_account": {
          "id": 3,
          "name": "BBVA Checking ****1234",
          "account_type": "debit"
        },
        "category": {
          "id": 12,
          "name": "Food",
          "icon": "utensils"
        },
        "is_transfer": false,
        "transfer_account": null,
        "created_at": "2026-04-15T08:00:00Z",
        "updated_at": "2026-04-15T08:00:00Z"
      }
    ]
  },
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_items": 98,
      "page_size": 20,
      "next_page": 2,
      "prev_page": null
    }
  }
}
```

### Field Notes

- `amount`: Negative for expenses, positive for income
- `concept`: AI-extracted cleaner description (may be null for manual transactions)
- `statement_file_id`: ID of the statement that imported this transaction (null for manual)
- `source`: `"manual"` | `"statement_file"` — only `manual` transactions can be edited/deleted
- `category`: `null` if uncategorized
- `transfer_account`: `null` if not a transfer

---

## GET /api/v1/transactions/:id

Get a single transaction.

### Response 200

Same structure as a single item in the list, wrapped in `data`:

```json
{
  "data": { ... transaction object ... }
}
```

### Response 404

```json
{
  "error": {
    "message": "Transaction not found",
    "code": "TRANSACTION_NOT_FOUND",
    "details": []
  }
}
```

---

## POST /api/v1/transactions

Create a manual transaction.

### Request Body

```json
{
  "transaction": {
    "bank_account_id": 3,
    "date": "2026-04-15",
    "description": "Coffee",
    "concept": "Morning coffee",
    "amount": -45.00,
    "transaction_type": "variable_expense",
    "merchant": "Starbucks",
    "reference": "REF-001",
    "category_id": 12
  }
}
```

### Response 201

```json
{
  "data": { ... transaction object ... },
  "message": "Transaction created successfully"
}
```

---

## PATCH /api/v1/transactions/:id

Update a manual transaction. Only transactions with `source = "manual"` can be updated.

### Response 200

```json
{
  "data": { ... updated transaction object ... },
  "message": "Transaction updated successfully"
}
```

### Response 403

```json
{
  "error": {
    "message": "Only manual transactions can be updated",
    "code": "UPDATE_NOT_ALLOWED",
    "details": []
  }
}
```

---

## DELETE /api/v1/transactions/:id

Delete a manual transaction.

### Response 200

```json
{
  "data": {
    "message": "Transaction deleted successfully"
  }
}
```

### Response 403

```json
{
  "error": {
    "message": "Only manual transactions can be deleted",
    "code": "DESTROY_NOT_ALLOWED",
    "details": []
  }
}
```

---

## GET /api/v1/transactions/summary

Returns aggregate statistics for filtered transactions.

### Query Parameters

Same filter params as the index endpoint (except pagination/sort).

### Response 200

```json
{
  "data": {
    "total_income": 15000.00,
    "total_expenses": 8500.00,
    "net": 6500.00,
    "transaction_count": 47,
    "income_count": 3,
    "expense_count": 44
  }
}
```
