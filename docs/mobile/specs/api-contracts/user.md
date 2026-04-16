# API Contract: User

> Updated: 2026-04-16 (Phase 2)

Base path: `/api/v1/user`
Auth: JWT Bearer required (both endpoints)

---

## GET /api/v1/user

Returns the authenticated user's profile.

### Request

```
GET /api/v1/user
Authorization: Bearer <access_token>
```

No request body or query params.

### Response 200

```json
{
  "data": {
    "id": 1,
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Doe",
    "full_name": "Jane Doe",
    "confirmed": true,
    "avatar_url": "https://...",
    "subscription_status": "trial_active",
    "trial_ends_at": "2026-05-16T12:00:00Z",
    "created_at": "2026-04-16T10:00:00Z",
    "updated_at": "2026-04-16T10:00:00Z"
  }
}
```

### `subscription_status` values

| Value | Meaning |
|-------|---------|
| `trial_active` | Within trial period — full access |
| `active` | Paid subscription active |
| `trial_ended` | Trial expired, no paid subscription |
| `payment_failed` | Paid sub exists but payment past due |
| `subscription_required` | No trial and no subscription |
| `none` | Unknown state (fallback) |

### Response 401

```json
{
  "error": {
    "message": "Unauthorized",
    "code": "UNAUTHORIZED",
    "details": []
  }
}
```

---

## PATCH /api/v1/user

Update the authenticated user's profile.

### Request

```
PATCH /api/v1/user
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "user": {
    "first_name": "Jane",
    "last_name": "Smith",
    "avatar_url": "https://..."
  }
}
```

### Response 200

Same shape as GET `/api/v1/user` response, with updated values.

### Response 422

```json
{
  "error": {
    "message": "Failed to update user",
    "code": "VALIDATION_ERROR",
    "details": [
      { "field": "email", "message": "Email has already been taken", "code": "TAKEN" }
    ]
  }
}
```
