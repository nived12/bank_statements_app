# API Contract: Banks

> Created: 2026-04-16 (Phase 2)

Base path: `/api/v1/banks`
Auth: **Not required** — public endpoint

---

## GET /api/v1/banks

Returns all active banks. Used by mobile bank picker when creating a bank account.

### Request

```
GET /api/v1/banks
GET /api/v1/banks?account_type=debit
GET /api/v1/banks?account_type=credit
```

No `Authorization` header required.

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `account_type` | string | No | Filter by compatibility: `debit` or `credit` |

### Response 200

```json
{
  "data": {
    "banks": [
      {
        "id": 1,
        "code": "bbva",
        "name": "BBVA Bancomer",
        "logo_url": "https://cdn.vitt.io/banks/bbva.png",
        "supported_type": "both"
      },
      {
        "id": 2,
        "code": "santander",
        "name": "Santander",
        "logo_url": "https://cdn.vitt.io/banks/santander.png",
        "supported_type": "debit"
      }
    ]
  }
}
```

### `supported_type` values

| Value | Meaning |
|-------|---------|
| `debit` | Bank supports debit/savings accounts only |
| `credit` | Bank supports credit accounts only |
| `both` | Bank supports both debit and credit |
| `null` | Bank is listed but not yet supported for statement parsing |

### Notes

- Only `active: true` banks are returned
- Results ordered alphabetically by name (database collation — case-insensitive)
- `logo_url` may be `null` if no logo has been configured
- When `account_type=debit`: returns banks with `supported_type = "debit"` or `"both"`
- When `account_type=credit`: returns banks with `supported_type = "credit"` or `"both"`
