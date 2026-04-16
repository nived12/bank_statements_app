# API Contract: Authentication

> Reviewed: 2026-04-16 (Phase 2 — no changes, documenting existing behavior)

Base path: `/api/v1/`
Auth: No Bearer token required on these endpoints (except `/logout`)

---

## POST /api/v1/login

Authenticate and receive JWT tokens.

### Request

```json
{
  "user": {
    "email": "user@example.com",
    "password": "secret123"
  }
}
```

### Response 200

```json
{
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "expires_in": 900,
    "user": {
      "id": 1,
      "email": "user@example.com",
      "first_name": "Jane",
      "last_name": "Doe",
      "full_name": "Jane Doe",
      "confirmed": true,
      "avatar_url": "https://..."
    }
  },
  "message": "Successfully logged in"
}
```

### Response 401

```json
{
  "error": {
    "message": "Invalid email or password",
    "code": "INVALID_CREDENTIALS",
    "details": []
  }
}
```

### Error Codes

| Code | HTTP | Meaning |
|------|------|---------|
| `INVALID_CREDENTIALS` | 401 | Wrong email or password |
| `EMAIL_NOT_CONFIRMED` | 401 | Account not confirmed |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many login attempts |

---

## POST /api/v1/signup

Create a new account.

### Request

```json
{
  "user": {
    "email": "user@example.com",
    "password": "secret123",
    "password_confirmation": "secret123",
    "first_name": "Jane",
    "last_name": "Doe"
  }
}
```

### Response 201

Same shape as login response (tokens + user).

### Response 422

```json
{
  "error": {
    "message": "Failed to create account",
    "code": "VALIDATION_ERROR",
    "details": [
      { "field": "email", "message": "Email has already been taken", "code": "TAKEN" }
    ]
  }
}
```

---

## POST /api/v1/refresh

Exchange a refresh token for a new token pair.

### Request

```json
{
  "refresh_token": "eyJ..."
}
```

### Response 200

```json
{
  "data": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "token_type": "Bearer",
    "expires_in": 900
  }
}
```

### Notes

- Both `access_token` and `refresh_token` are rotated on each refresh (JTI rotation)
- Old refresh token is invalidated after use
- On `401` from this endpoint, the mobile app must log out the user

---

## DELETE /api/v1/logout

Invalidate the current token pair by rotating JTI.

### Request

```
DELETE /api/v1/logout
Authorization: Bearer <access_token>
```

### Response 200

Empty body with `200 OK`.

### Notes

- All existing tokens for the user are invalidated
- Mobile should clear stored tokens from SecureStore on this response

---

## Token Lifecycle

```
Login/Signup → access_token (15 min) + refresh_token (7 days)
               │
               ▼ access_token expires
POST /refresh → new access_token + new refresh_token
               │
               ▼ refresh_token expires or 401 on refresh
               → Force logout, redirect to login
```

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `POST /login` (by IP) | 10/hour |
| `POST /login` (by email) | 5/hour |
| `POST /signup` (by IP) | 5/hour |
| `POST /refresh` (by IP) | 20/hour |
| All API endpoints (by user) | 100/minute |
