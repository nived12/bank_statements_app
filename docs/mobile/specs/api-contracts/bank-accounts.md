# API Contract: Bank Accounts

> Reviewed: 2026-04-16 (Phase 2 — no endpoint changes, contract documented)

Base path: `/api/v1/bank_accounts`
Auth: JWT Bearer required on all endpoints

---

## GET /api/v1/bank_accounts

List all bank accounts for the authenticated user.

### Response 200

```json
{
  "data": {
    "bank_accounts": [
      {
        "id": 3,
        "name": "BBVA Checking ****1234",
        "custom_name": null,
        "bank_name": "BBVA Bancomer",
        "bank_id": 1,
        "account_type": "debit",
        "currency": "MXN",
        "opening_balance": "0.0",
        "balance": 22000.50,
        "transactions_count": 89,
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-04-15T08:00:00Z"
      }
    ]
  },
  "meta": {
    "pagination": { ... }
  }
}
```

---

## GET /api/v1/bank_accounts/:id

Get a single bank account.

### Response 200

```json
{
  "data": { ... bank account object ... }
}
```

### Response 404

```json
{
  "error": {
    "message": "Bank account not found",
    "code": "BANK_ACCOUNT_NOT_FOUND",
    "details": []
  }
}
```

---

## POST /api/v1/bank_accounts

Create a new bank account.

### Notes

- Use `GET /api/v1/banks` to get the `bank_id` for the picker
- `account_type` must match bank's `supported_type` (or `both`)

### Request Body

```json
{
  "bank_account": {
    "bank_id": 1,
    "account_type": "debit",
    "custom_name": "My Checking",
    "currency": "MXN",
    "opening_balance": 5000.00
  }
}
```

### Response 201

```json
{
  "data": { ... bank account object ... },
  "message": "Bank account created successfully"
}
```

---

## PATCH /api/v1/bank_accounts/:id

Update a bank account's metadata (`custom_name`, `opening_balance`, etc.).

### Response 200

```json
{
  "data": { ... updated bank account object ... },
  "message": "Bank account updated successfully"
}
```

---

## DELETE /api/v1/bank_accounts/:id

Delete a bank account and all associated transactions and statement files.

### Response 204

Empty body (no content).
