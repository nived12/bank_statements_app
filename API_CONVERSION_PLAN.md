# API Conversion Plan for React Native Integration

## Current State Analysis

Your application currently has:
- **Rails 8** with Hotwire (Turbo + Stimulus) for web frontend
- **Session-based authentication** (via `session[:user_id]`)
- **Some existing JSON endpoints** using Jbuilder (transactions, categories, savings, debts, goals)
- **Service objects pattern** for business logic (excellent for API reuse!)
- **PostgreSQL database** with proper relationships
- **Comprehensive testing** with RSpec

---

## Step-by-Step Implementation Plan

### Phase 1: Authentication Strategy (Foundation)

#### Step 1.1: Choose Authentication Mechanism
**Decision Required:** Token-based authentication for mobile clients

**Options:**
- **JWT (JSON Web Tokens)** - Most common for mobile APIs
- **API Keys** - Simpler but less secure
- **OAuth 2.0** - If you want third-party integrations

**Recommended:** JWT with refresh tokens

**What needs to happen:**
1. Add `jwt` gem to Gemfile
2. Create `lib/json_web_token.rb` utility class for encoding/decoding
3. Add `refresh_token` and `jti` (JWT ID) columns to `users` table
4. Create token generation/validation service objects

#### Step 1.2: Create API Authentication System
**New files to create:**
1. `app/controllers/api/v1/authentication_controller.rb` - Login/logout/refresh endpoints
2. `app/controllers/concerns/api_authenticatable.rb` - JWT validation concern
3. `app/services/auth/generate_tokens_service.rb` - Token generation
4. `app/services/auth/refresh_tokens_service.rb` - Token refresh logic
5. `app/services/auth/revoke_tokens_service.rb` - Logout/revoke tokens

**Key consideration:** Keep session-based auth for web, use JWT for mobile (detect via `Accept: application/json` header or `/api/` namespace)

---

### Phase 2: API Structure & Namespacing

#### Step 2.1: Create API Namespace
**What to do:**
1. Create directory structure:
   ```
   app/controllers/api/
   app/controllers/api/v1/
   app/controllers/api/v1/base_controller.rb
   ```

2. Update `config/routes.rb` to add:
   ```ruby
   namespace :api do
     namespace :v1 do
       # API routes here
     end
   end
   ```

#### Step 2.2: Create Base API Controller
**File:** `app/controllers/api/v1/base_controller.rb`

**What it should include:**
- Skip CSRF token verification for API requests
- Include `ApiAuthenticatable` concern
- JSON-only responses
- Custom error handling (JSON format)
- Rate limiting headers
- CORS configuration (if needed for web clients)
- Override `current_user` to use JWT instead of session

**Key point:** Don't inherit from `ApplicationController` directly - create separate base to avoid web-specific concerns (Turbo, CSRF, session timeout, etc.)

---

### Phase 3: API Endpoint Creation

#### Step 3.1: Priority Endpoints for Mobile
Create API versions of these controllers (in priority order):

**Must-have (Core functionality):**
1. `api/v1/authentication_controller.rb` - Login, signup, logout, refresh token
2. `api/v1/users_controller.rb` - Profile, update settings
3. `api/v1/dashboard_controller.rb` - Main dashboard data
4. `api/v1/transactions_controller.rb` - CRUD transactions
5. `api/v1/categories_controller.rb` - Categories list
6. `api/v1/bank_accounts_controller.rb` - Bank accounts management
7. `api/v1/statement_files_controller.rb` - Upload statements

**Important (Enhanced functionality):**
8. `api/v1/savings_controller.rb` - Savings goals
9. `api/v1/debts_controller.rb` - Debt tracking
10. `api/v1/goals_controller.rb` - Financial goals

**Nice-to-have:**
11. `api/v1/password_resets_controller.rb` - Password reset flow
12. `api/v1/email_confirmations_controller.rb` - Email confirmation

#### Step 3.2: Controller Pattern
**For each controller:**
1. Copy business logic structure from existing web controller
2. **Reuse existing service objects** (this is key! Don't duplicate logic)
3. Remove Turbo/HTML-specific code
4. Return JSON responses only
5. Use existing Jbuilder templates where they exist
6. Create new Jbuilder templates where needed

**Example structure:**
```ruby
module Api
  module V1
    class TransactionsController < Api::V1::BaseController
      def index
        result = Transactions::Lister.call(current_user, request_params)

        if result.success?
          @transactions = result.payload[:transactions]
          @pagy, @transactions = pagy(@transactions, items: 20)
          # Renders index.json.jbuilder
        else
          render_error(result.errors)
        end
      end
    end
  end
end
```

---

### Phase 4: Response Format Standardization

#### Step 4.1: Consistent Response Structure
**Define standard response formats:**

**Success:**
```json
{
  "data": { /* resource or collection */ },
  "meta": { /* pagination, filters, etc */ },
  "message": "Optional success message"
}
```

**Error:**
```json
{
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "details": [
      { "field": "email", "message": "is invalid" }
    ]
  }
}
```

#### Step 4.2: Reuse & Extend Jbuilder Templates
**What you already have (great!):**
- `app/views/transactions/index.json.jbuilder`
- `app/views/categories/index.json.jbuilder`
- `app/views/savings/index.json.jbuilder`
- `app/views/debts/index.json.jbuilder`

**What to do:**
1. Move shared templates to `app/views/api/v1/shared/`
2. Create API-specific templates in `app/views/api/v1/[resource]/`
3. Add more detailed responses for mobile needs (e.g., include related data to reduce API calls)
4. Add `meta` information (pagination, timestamps, etc.)

**Example enhancement:**
```ruby
# app/views/api/v1/transactions/index.json.jbuilder
json.data do
  json.transactions @transactions do |transaction|
    json.partial! 'api/v1/transactions/transaction', transaction: transaction
  end
end

json.meta do
  json.pagination do
    json.page @pagy.page
    json.total_pages @pagy.pages
    json.total_count @pagy.count
    json.per_page @pagy.items
  end

  json.stats @stats if @stats.present?
  json.filters @filters if @filters.present?
end
```

---

### Phase 5: Error Handling & Validation

#### Step 5.1: Standardized Error Responses
**Create:**
1. `app/controllers/concerns/api_error_handler.rb`
2. Standard error codes enum
3. Error serializer for consistent format

**Handle these error types:**
- Authentication errors (401)
- Authorization errors (403)
- Validation errors (422)
- Not found errors (404)
- Rate limit errors (429)
- Server errors (500)

#### Step 5.2: Input Validation
**What to do:**
1. Use strong parameters (already in place - good!)
2. Add API-specific parameter validation
3. Return detailed validation errors for mobile to display
4. Consider request size limits for file uploads

---

### Phase 6: File Uploads (Statement Files)

#### Step 6.1: Handle Multipart Uploads
**Challenge:** Statement file uploads need special handling for mobile

**What to do:**
1. Update `api/v1/statement_files_controller.rb` to accept base64 encoded files OR multipart form data
2. Add file size validation
3. Add file type validation (PDF only)
4. Return upload progress webhook URL for long-running uploads
5. Consider chunked uploads for large files

#### Step 6.2: Background Job Status
**Since you use Sidekiq:**
1. Return job ID after upload
2. Create `api/v1/jobs_controller.rb` for status checking
3. Mobile app can poll for completion
4. Consider webhooks or push notifications for completion

---

### Phase 7: Optimization for Mobile

#### Step 7.1: Reduce API Calls
**Strategy:**
1. Include related data in responses (eager loading)
2. Create composite endpoints where it makes sense
   - Example: Dashboard endpoint returns everything in one call
3. Support field selection (`?fields=id,name,amount`)
4. Support resource inclusion (`?include=bank_account,category`)

**Example:**
```ruby
# GET /api/v1/transactions/123?include=bank_account,category
# Returns transaction with nested bank_account and category data
```

#### Step 7.2: Pagination & Filtering
**Already using Pagy (good!):**
1. Ensure all list endpoints support pagination
2. Add cursor-based pagination option for infinite scroll
3. Support same filters as web (already defined in request_params)
4. Add date range presets (this_month, last_month, this_year)

#### Step 7.3: Caching Strategy
**Recommendations:**
1. Add `ETag` headers for GET requests
2. Support `If-None-Match` for 304 responses
3. Cache frequently accessed data (categories, bank accounts)
4. Use Rails cache for expensive queries (dashboard stats)

---

### Phase 8: Testing Strategy

#### Step 8.1: Request Specs for API
**Create:**
`spec/requests/api/v1/` directory structure

**For each API endpoint, test:**
1. **Authentication:** Unauthorized access returns 401
2. **Authorization:** Users can only access their own data
3. **Happy path:** Valid requests return correct data structure
4. **Validation:** Invalid data returns 422 with error details
5. **Edge cases:** Empty results, pagination edge cases
6. **Response format:** JSON structure matches expectations

**Example test structure:**
```ruby
# spec/requests/api/v1/transactions_spec.rb
RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{jwt_token_for(user)}" } }

  describe "GET /api/v1/transactions" do
    context "when authenticated" do
      it "returns transactions list with pagination" do
        create_list(:transaction, 25, user: user)

        get "/api/v1/transactions", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].size).to eq(20)
        expect(json["meta"]["pagination"]["total_count"]).to eq(25)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/transactions"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

#### Step 8.2: Service Object Tests
**Good news:** Your existing service object tests don't need changes! They're already testing business logic independently.

---

### Phase 9: Documentation

#### Step 9.1: API Documentation
**Create documentation:**
1. `docs/API.md` - Complete API reference
2. Include for each endpoint:
   - Path and HTTP method
   - Authentication requirements
   - Request parameters
   - Request body example
   - Response format example
   - Error responses
   - Rate limits

**Consider tools:**
- **Swagger/OpenAPI** - Interactive API documentation
- **Postman Collection** - Easy for testing
- **RSpec API Documentation** gem - Generate docs from tests

#### Step 9.2: Mobile Integration Guide
**Create:**
`docs/MOBILE_INTEGRATION.md`

**Include:**
1. Authentication flow diagram
2. Token refresh strategy
3. Error handling guidelines
4. Offline data handling recommendations
5. File upload best practices
6. Push notification setup (future)

---

### Phase 10: Security & Rate Limiting

#### Step 10.1: Rate Limiting
**You already have rack-attack (good!):**
1. Configure API-specific rate limits (more lenient than web)
2. Different limits for authenticated vs unauthenticated
3. Special limits for expensive endpoints (dashboard, reports)
4. Return rate limit headers:
   - `X-RateLimit-Limit`
   - `X-RateLimit-Remaining`
   - `X-RateLimit-Reset`

#### Step 10.2: Security Measures
**Implement:**
1. CORS configuration if web client will call API
2. Request size limits
3. SQL injection protection (ActiveRecord handles this)
4. Mass assignment protection (strong parameters - already done)
5. Sensitive data filtering in logs (passwords, tokens)
6. HTTPS enforcement in production
7. API versioning for breaking changes

---

### Phase 11: Timezone & Localization

#### Step 11.1: Timezone Handling
**Challenge:** Mobile app needs to send user timezone

**Solution:**
1. Accept `X-Timezone` header in API requests
2. Use it to format dates in responses
3. Store user's timezone preference in database
4. All dates stored in UTC (already following this - good!)

#### Step 11.2: Internationalization
**You already support English/Spanish (good!):**
1. Accept `Accept-Language` header or `?locale=` parameter
2. Return translated error messages
3. Return translated categories/enums
4. Consider including translations in response for offline use

---

### Phase 12: Rollout Strategy

#### Step 12.1: Incremental Rollout
**Recommended approach:**
1. **Week 1-2:** Authentication & Users (Phase 1, 2)
2. **Week 3-4:** Core endpoints (Dashboard, Transactions, Categories)
3. **Week 5-6:** Bank Accounts & Statement Files
4. **Week 7-8:** Savings, Debts, Goals
5. **Week 9-10:** Testing, optimization, documentation

#### Step 12.2: Backwards Compatibility
**Important:**
- Keep web endpoints unchanged
- API and web can coexist
- Share service objects between both
- Use namespacing to prevent conflicts

---

## Summary of Key Files to Create

### New Controllers (15 files)
```
app/controllers/api/v1/base_controller.rb
app/controllers/api/v1/authentication_controller.rb
app/controllers/api/v1/users_controller.rb
app/controllers/api/v1/dashboard_controller.rb
app/controllers/api/v1/transactions_controller.rb
app/controllers/api/v1/categories_controller.rb
app/controllers/api/v1/bank_accounts_controller.rb
app/controllers/api/v1/statement_files_controller.rb
app/controllers/api/v1/savings_controller.rb
app/controllers/api/v1/debts_controller.rb
app/controllers/api/v1/goals_controller.rb
app/controllers/api/v1/password_resets_controller.rb
app/controllers/api/v1/email_confirmations_controller.rb
app/controllers/api/v1/jobs_controller.rb
```

### New Concerns (2 files)
```
app/controllers/concerns/api_authenticatable.rb
app/controllers/concerns/api_error_handler.rb
```

### New Services (3 files)
```
app/services/auth/generate_tokens_service.rb
app/services/auth/refresh_tokens_service.rb
app/services/auth/revoke_tokens_service.rb
```

### New Jbuilder Templates (~20 files)
```
app/views/api/v1/[resource]/index.json.jbuilder
app/views/api/v1/[resource]/show.json.jbuilder
app/views/api/v1/shared/_error.json.jbuilder
app/views/api/v1/shared/_pagination.json.jbuilder
```

### New Tests (~30 files)
```
spec/requests/api/v1/[resource]_spec.rb
spec/services/auth/*_spec.rb
```

### Configuration Updates
```
config/routes.rb (add API namespace)
config/initializers/cors.rb (if needed)
config/initializers/rack_attack.rb (API rate limits)
Gemfile (add jwt gem)
```

### Documentation
```
docs/API.md
docs/MOBILE_INTEGRATION.md
```

---

## Estimated Effort

- **Total new files:** ~70-80
- **Modified files:** ~5
- **Lines of code:** ~3,000-4,000 (including tests)
- **Timeline:** 8-10 weeks for full implementation
- **MVP (Auth + Dashboard + Transactions):** 2-3 weeks

---

## Key Advantages of This Approach

1. ✅ **Reuses existing service objects** - No business logic duplication
2. ✅ **Maintains web functionality** - No breaking changes
3. ✅ **Follows Rails conventions** - API versioning, RESTful routes
4. ✅ **Testable** - Request specs for each endpoint
5. ✅ **Scalable** - Easy to add v2 later
6. ✅ **Secure** - JWT tokens, rate limiting, proper authorization
7. ✅ **Mobile-optimized** - Reduced API calls, efficient responses
8. ✅ **Documented** - Clear API reference for React Native team

---

## Next Steps

Once you're ready to proceed, we can start with:

1. **Phase 1:** Set up JWT authentication system
2. **Phase 2:** Create the API namespace and base controller
3. **Phase 3:** Start with the authentication endpoints (login, signup, logout)
4. **Then gradually add:** Dashboard → Transactions → Categories → Bank Accounts → etc.

Each phase can be developed, tested, and verified independently before moving to the next one.
