# API Gaps & Audit Findings

> Owned by `/be-dev`. Completed: 2026-04-16 (Phase 1 audit)

## Audit Summary

All 14 API v1 controllers audited. The API is **well-structured and production-ready** for most use cases. Auth is solid, service objects are clean, error codes are consistent, and pagination is in place. There are **5 critical gaps** and **several medium/low issues** to address before mobile development begins.

---

## 🔴 Critical Gaps (Must Fix in Phase 2)

### 1. CORS Not Configured
- **Impact**: Mobile web clients and Swagger UI cross-origin requests will fail
- **Note**: Native apps (React Native, Flutter) don't send `Origin` headers, so CORS is mainly needed for Expo Go web preview, Swagger UI, and development tooling
- **Fix**: Add `rack-cors` gem + `config/initializers/cors.rb`

### 2. Goals API Missing from v1
- Web routes have `resources :goals` (full CRUD)
- **No `Api::V1::GoalsController` exists**
- No Jbuilder views for goals API
- **Fix**: Create controller + Jbuilder views + routes in Phase 2

### 3. User Partial Inconsistency (auth vs users)
Two different user Jbuilder partials with different fields:

| Field | `authentication/_user.json.jbuilder` | `users/_user.json.jbuilder` |
|-------|--------------------------------------|-----------------------------|
| id | ✅ | ✅ |
| email | ✅ | ✅ |
| first_name | ✅ | ✅ |
| last_name | ✅ | ✅ |
| full_name | ✅ | ❌ **missing** |
| confirmed | ✅ | ❌ **missing** |
| avatar_url | ✅ | ✅ |
| created_at | ❌ | ✅ |
| updated_at | ❌ | ✅ |

- **Impact**: `GET /api/v1/user` doesn't return `confirmed` or `full_name` — mobile can't show profile status
- **Fix**: Merge partials or add missing fields to `users/_user.json.jbuilder`

### 4. Missing Fields: `subscription_status` and `trial_ends_at` on User
- Mobile needs to know if the user is on trial, subscribed, or blocked
- `UsersController#show` returns no subscription info at all
- `subscription_access_result` is only called on `StatementFilesController#create`
- **Fix**: Add `subscription_status`, `trial_ends_at`, `is_trial_active` to user response

### 5. Destroy Actions Use Non-Standard Envelope
Two controllers return raw JSON instead of the documented envelope:

```ruby
# TransactionsController#destroy — WRONG
render json: { message: "Transaction deleted successfully" }, status: :ok

# CategoriesController#destroy — WRONG  
render json: { message: "Category deleted successfully" }, status: :ok
```

Should be either `head(:no_content)` (like BankAccounts) or `render json: { data: { message: "..." } }`.
- **Impact**: Mobile clients expecting consistent envelope will break on delete responses

---

## 🟡 Medium Gaps (Fix in Phase 2)

### 6. Missing `concept` Field in Transaction Partial
- `TransactionsController` accepts `concept` in `transaction_params`
- `_transaction.json.jbuilder` does **not render** `concept` or `confidence` fields
- Missing fields: `concept`, `category_confidence`, `transaction_type_confidence`, `statement_file_id`
- **Fix**: Add to `_transaction.json.jbuilder`

### 7. Missing `category_id` Filter for Transactions
- `request_params` in `TransactionsController` does not include `category_id` filter
- Mobile users will want to filter transactions by category
- **Fix**: Add `category_id`, `source`, `min_amount`, `max_amount` to `request_params` and `Transactions::Lister`

### 8. No Banks Index Endpoint
- Mobile bank account creation needs a bank picker
- No `GET /api/v1/banks` endpoint exists
- Users must know their bank's ID to create a bank account — not user-friendly on mobile
- **Fix**: Create `Api::V1::BanksController#index` (read-only, no auth required or optional)

### 9. Dashboard Error Uses Wrong Format
```ruby
# DashboardController#show — WRONG error format
render json: { error: response.errors.full_messages.to_sentence }, status: :internal_server_error
```
Should use `render_error("DASHBOARD_LOAD_FAILED", ...)` to be consistent with all other controllers.

### 10. Rack::Attack Uses `MemoryStore`
```ruby
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
```
- **Problem**: `MemoryStore` is per-process. With multiple Puma workers, each worker has its own counter — rate limits are effectively divided by worker count
- **Fix**: Use `Rails.cache` (which uses Redis in production) instead

### 11. Rate Limiting Missing General API Throttle
- Auth endpoints are throttled ✅
- Statement file uploads throttled ✅
- **No throttle on**: `GET /api/v1/transactions`, `GET /api/v1/dashboard`, other read endpoints
- A mobile client polling the dashboard every second would be unthrottled
- **Fix**: Add `100 req/min per authenticated user` for general API traffic

### 12. `PasswordResetsController#update` Returns `head(:ok)` with No Body
- After a successful password reset, mobile gets an empty 200 response
- Mobile should get a confirmation message
- **Fix**: Render a Jbuilder response with a success message

### 13. `refresh` Response Missing User Object
- `refresh.json.jbuilder` only returns tokens
- Mobile often needs to refresh both the token and the user profile in one call
- **Fix**: Optionally include user object in refresh response (or document it's intentional)

---

## 🟢 Low Priority / Phase 6+ (Not needed for MVP)

### 14. No User Settings/Preferences Endpoint
- `UserSettings` model only stores `processing_strategy`
- Mobile will eventually need: preferred currency, locale, notification preferences
- Current settings are minimal — `processing_strategy` only
- **Phase 6+**: Add `GET/PATCH /api/v1/user/settings` when push notifications are built

### 15. No Device Token Registration
- No `POST /api/v1/devices` endpoint for push notification tokens
- **Phase 10**: Add when push notifications are implemented

### 16. No Category Rules API
- `CategoryRules` model and web controller exist, but no API v1 endpoint
- Mobile may want to show/manage category rules
- **Phase 6+**: Add if needed

### 17. No App Version Check Endpoint
- No endpoint for mobile to check minimum required version
- **Phase 10+**: Add `GET /api/v1/app/version` or use response headers

### 18. `BankAccount` `index` N+1 Risk
- `BankAccountsController#index` does `includes(:bank)` but `_bank_account.json.jbuilder` calls `bank_account.transactions.size`
- This is an N+1 query — each account makes a separate `COUNT(*) transactions` query
- **Fix**: Add `includes(:transactions)` to the index query, or use a counter cache

### 19. `BankAccount` Show Missing Recent Transactions
- Mobile bank account detail screen will want recent transactions
- `bank_accounts/show.json.jbuilder` only renders the bank account partial (no transactions)
- **Fix in Phase 4**: Add `recent_transactions` to show response, or document that mobile should call `GET /api/v1/transactions?bank_account_id=X`

### 20. Logout Returns `head(:ok)` with No Body
- `DELETE /api/v1/logout` returns empty 200
- Consistent with REST conventions but mobile might want a confirmation message
- **Low priority**: Document this as intentional

---

## MVP Endpoint Readiness Matrix

| Endpoint | Status | Issues |
|----------|--------|--------|
| `POST /api/v1/login` | ✅ Ready | None |
| `POST /api/v1/signup` | ✅ Ready | None |
| `POST /api/v1/refresh` | ✅ Ready | Missing user object (low priority) |
| `DELETE /api/v1/logout` | ✅ Ready | Empty body (acceptable) |
| `GET /api/v1/dashboard` | ⚠️ Minor fix | Wrong error format (easy fix) |
| `GET /api/v1/transactions` | ⚠️ Fix needed | Missing `category_id` filter, `concept` field |
| `GET /api/v1/transactions/:id` | ⚠️ Fix needed | Missing `concept`, `statement_file_id` |
| `POST /api/v1/transactions` | ✅ Ready | None |
| `PATCH /api/v1/transactions/:id` | ✅ Ready | None |
| `DELETE /api/v1/transactions/:id` | ⚠️ Fix needed | Non-standard response envelope |
| `GET /api/v1/transactions/summary` | ✅ Ready | None |
| `GET /api/v1/bank_accounts` | ⚠️ Minor | N+1 risk on transactions_count |
| `GET /api/v1/bank_accounts/:id` | ⚠️ Minor | No recent transactions |
| `POST /api/v1/bank_accounts` | ✅ Ready | No bank picker endpoint |
| `PATCH /api/v1/bank_accounts/:id` | ✅ Ready | None |
| `DELETE /api/v1/bank_accounts/:id` | ✅ Ready | None (head :no_content) |
| `GET /api/v1/user` | 🔴 Fix needed | Missing `confirmed`, `full_name`, `subscription_status` |
| `PATCH /api/v1/user` | ✅ Ready | None |
| `GET /api/v1/categories` | ✅ Ready | None |
| `POST /api/v1/email_confirmations` | ✅ Ready | None |
| `PATCH /api/v1/email_confirmations/:token` | ✅ Ready | None |
| `POST /api/v1/password_resets` | ✅ Ready | None |
| `PATCH /api/v1/password_resets/:token` | ⚠️ Minor | Returns `head(:ok)`, no body |

---

## Phase 2 Implementation Plan

### Must-Do Before Mobile Development

| Task | Effort | Priority |
|------|--------|----------|
| Add `rack-cors` + `cors.rb` | 30min | Critical |
| Fix `users/_user.json.jbuilder` (add confirmed, full_name, subscription_status) | 30min | Critical |
| Fix `destroy` envelope in Transactions + Categories | 15min | Critical |
| Fix Dashboard error format | 15min | Critical |
| Add `concept` + `statement_file_id` to `_transaction.json.jbuilder` | 15min | Medium |
| Add `category_id` filter to `TransactionsController` | 30min | Medium |
| Create `Api::V1::BanksController#index` | 45min | Medium |
| Fix `Rack::Attack` to use Rails cache (Redis) | 15min | Medium |
| Add general API rate throttle | 15min | Medium |
| Create Goals API v1 (controller + views + routes) | 2hrs | High (Phase 6) |
| Add `GET /api/v1/user/settings` | 1hr | Low (Phase 10) |
| Add `POST /api/v1/devices` | 1hr | Low (Phase 10) |

### Write API Contracts (after fixes)
Contracts to document in `docs/mobile/specs/api-contracts/`:
- `auth.md`
- `dashboard.md`
- `transactions.md`
- `bank-accounts.md`
- `user.md`
- `banks.md`
- `categories.md`
