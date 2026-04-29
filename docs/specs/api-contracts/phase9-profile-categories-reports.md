# Phase 9 API Contracts — Profile, Categories, Merchant Rules, Reports

## User Profile

### GET /api/v1/user
Returns current user profile.
```json
{
  "data": {
    "id": 1,
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Doe",
    "full_name": "Jane Doe",
    "avatar_url": "https://...",
    "confirmed": true,
    "subscription_status": "trial_active",
    "trial_ends_at": "2026-05-01T00:00:00Z",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-04-27T00:00:00Z"
  }
}
```

### PATCH /api/v1/user
Update profile fields. All fields optional.
```json
// Request
{ "user": { "first_name": "Jane", "last_name": "Doe", "email": "new@example.com", "avatar_url": "https://..." } }

// Response: same as GET /api/v1/user
```
**Notes:**
- Email must be unique; 422 VALIDATION_ERROR if taken
- OAuth users can update email (they have a random password set on creation)
- No re-confirmation email is triggered on email change in this version

### PATCH /api/v1/user/password
Change password for non-OAuth users only.
```json
// Request
{ "user": { "current_password": "oldpass123", "password": "newpass456", "password_confirmation": "newpass456" } }

// Response (200)
{ "data": { "message": "Password updated successfully" }, "message": "Password updated successfully" }
```
**Errors:**
- `OAUTH_ACCOUNT` (422) — cannot change password on Google-linked account
- `INVALID_CURRENT_PASSWORD` (422) — current password does not match
- `VALIDATION_ERROR` (422) — new password too short or confirmation mismatch

---

## Categories

### GET /api/v1/categories
Returns paginated list of top-level categories (parent_id: null) with children.
```json
{
  "data": {
    "categories": [
      {
        "id": 1, "name": "Food", "icon": "utensils", "color": "#6366f1",
        "parent_id": null, "transactions_count": 15,
        "children": [
          { "id": 2, "name": "Groceries", "icon": null, "color": null, "parent_id": 1, "transactions_count": 8 }
        ]
      }
    ]
  },
  "meta": { "current_page": 1, "total_items": 10, "page_size": 20 }
}
```

### POST /api/v1/categories
```json
// Request
{ "category": { "name": "Transport", "icon": "car", "color": "#f59e0b", "parent_id": null } }
```

### PATCH /api/v1/categories/:id
Same fields as POST. All optional.

---

## Merchant Rules

### GET /api/v1/merchant_rules
Returns active exact-match merchant-to-category mappings.
Optional `?merchant=<name>` filter (case-insensitive exact match).
```json
{
  "data": [
    {
      "id": 5, "merchant_name": "Amazon", "pattern": "Amazon", "category_id": 3,
      "hits_count": 12, "active": true,
      "category": { "id": 3, "name": "Shopping", "icon": "shopping-bag", "color": "#8b5cf6" },
      "created_at": "2026-04-27T00:00:00Z", "updated_at": "2026-04-27T00:00:00Z"
    }
  ],
  "meta": { "current_page": 1, "total_items": 1, "page_size": 20 }
}
```

### POST /api/v1/merchant_rules
Upserts: if a rule for this merchant_name already exists, updates category_id.
```json
// Request
{ "merchant_rule": { "merchant_name": "Amazon", "category_id": 3 } }

// Response (201 created / 200 ok on update)
{ "data": { ...rule object... }, "message": "Merchant rule saved" }
```
**Errors:**
- `VALIDATION_ERROR` (422) — blank merchant_name

### DELETE /api/v1/merchant_rules/:id
```json
// Response (200)
{ "data": { "message": "Merchant rule deleted" } }
```
**Errors:**
- `MERCHANT_RULE_NOT_FOUND` (404)

---

## Reports

### GET /api/v1/reports/monthly?year=YYYY&month=MM
Downloads monthly PDF report. Always returns PDF binary.
Optional `?report_format=pdf` (currently only pdf is supported).

**Response:** `Content-Type: application/pdf`, `Content-Disposition: attachment; filename="vittio-reporte-2025-03.pdf"`

**Errors:**
- `INVALID_PERIOD` (422) — year out of range [2000, current+1] or month out of range [1, 12]
- `INVALID_FORMAT` (422) — unsupported report_format value

**Report contents:**
- Header: Vittio branding, period label, user name, generation date
- Summary cards: Total income, Total expenses, Net balance
- Top 5 expense categories with proportional bars
- Full transaction list for the period (date, description, category, account, amount)
- Footer with period and generation timestamp
