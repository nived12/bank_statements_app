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

### Phase 1: Authentication Strategy (Foundation) ✅ COMPLETED

#### Step 1.1: Choose Authentication Mechanism ✅
**Decision:** JWT (JSON Web Tokens) with 2025 best practices

**Implemented:**
1. ✅ Added `jwt` gem to Gemfile
2. ✅ Created `lib/json_web_token.rb` utility class with standard JWT claims (exp, iat, nbf, iss, aud, jti)
3. ✅ Added `jti` and `refresh_token_expires_at` columns to `users` table
4. ✅ Created dedicated JWT configuration (`config/initializers/jwt.rb`)
5. ✅ Separate JWT secret (not using `secret_key_base`)
6. ✅ Environment-based configuration (ENV["JWT_SECRET_KEY"])

**Railway Setup Required:** See [RAILWAY_JWT_SETUP.md](RAILWAY_JWT_SETUP.md) for production setup instructions

#### Step 1.2: Create API Authentication System ✅
**Completed files:**
1. ✅ `app/controllers/concerns/api_authenticatable.rb` - JWT validation concern
2. ✅ `app/services/auth/generate_tokens_service.rb` - Token generation (access: 15min, refresh: 7 days)
3. ✅ `app/services/auth/refresh_tokens_service.rb` - Token refresh logic with JTI validation
4. ✅ `app/services/auth/revoke_tokens_service.rb` - Logout/revoke tokens (JTI rotation)
5. ✅ Comprehensive specs (29 tests, all passing)

**Next:** Create `app/controllers/api/v1/authentication_controller.rb` in Phase 2

**Key features:**
- Stateless JWT tokens perfect for React Native
- Token revocation via JTI (JWT ID)
- Refresh token rotation for security
- Standard JWT claims for better security

---

### Phase 2: API Structure & Namespacing ✅ COMPLETED

#### Step 2.1: Create API Namespace ✅
**Implemented:**
1. ✅ Created directory structure:
   - `app/controllers/api/v1/`
   - `app/controllers/api/v1/base_controller.rb`
   - `app/controllers/api/v1/authentication_controller.rb`
   - `app/views/api/v1/` directory structure

2. ✅ Updated `config/routes.rb`:
   ```ruby
   namespace :api, defaults: { format: :json } do
     namespace :v1 do
       # Authentication endpoints
       post "/login", to: "authentication#login"
       post "/signup", to: "authentication#signup"
       post "/refresh", to: "authentication#refresh"
       delete "/logout", to: "authentication#logout"
     end
   end
   ```

#### Step 2.2: Create Base API Controller ✅
**File:** `app/controllers/api/v1/base_controller.rb`

**Implemented features:**
- ✅ Inherits from `ActionController::API` (not ApplicationController)
- ✅ Includes `ApiAuthenticatable` concern (JWT validation)
- ✅ Includes `ApiErrorHandler` concern (standardized error handling)
- ✅ JSON-only responses with Jbuilder templates
- ✅ Overrides `current_user` to use JWT authentication
- ✅ CSRF protection automatically disabled (ActionController::API)

#### Step 2.3: Authentication Controller ✅
**File:** `app/controllers/api/v1/authentication_controller.rb`

**Implemented endpoints:**
- ✅ POST `/api/v1/login` - Login with email/password
- ✅ POST `/api/v1/signup` - Create new user account
- ✅ POST `/api/v1/refresh` - Refresh access token
- ✅ DELETE `/api/v1/logout` - Revoke all tokens

#### Step 2.4: Jbuilder Templates ✅
**Created templates:**
- ✅ `app/views/api/v1/shared/error.json.jbuilder` - Shared error template
- ✅ `app/views/api/v1/authentication/_user.json.jbuilder` - User partial
- ✅ `app/views/api/v1/authentication/login.json.jbuilder`
- ✅ `app/views/api/v1/authentication/signup.json.jbuilder`
- ✅ `app/views/api/v1/authentication/refresh.json.jbuilder`
- ✅ `app/views/api/v1/authentication/logout.json.jbuilder`

**Best practices implemented:**
- ✅ Using `json.extract!` for multiple attributes
- ✅ Using partials for reusable components
- ✅ Implicit rendering (Rails auto-renders matching action template)
- ✅ Conditional attributes with `if present?`

#### Step 2.5: Error Handler Concern ✅
**File:** `app/controllers/concerns/api_error_handler.rb`

**Handles:**
- ✅ `ActiveRecord::RecordNotFound` → 404 Not Found
- ✅ `ActiveRecord::RecordInvalid` → 422 Unprocessable Entity
- ✅ `ActionController::ParameterMissing` → 400 Bad Request
- ✅ `StandardError` → 500 Internal Server Error (production only)
- ✅ Field-level validation error formatting

#### Step 2.6: Documentation ✅
**Created:**
- ✅ `API_DEVELOPMENT.md` - Comprehensive API development guidelines:
  - Architecture overview
  - JWT authentication flow
  - Jbuilder template best practices
  - Hybrid i18n approach (error codes + English fallback)
  - Response format standards
  - Error handling patterns
  - Testing guidelines
  - Versioning strategy
- ✅ Updated `DEVELOPMENT.md` with API reference
- ✅ Added `:confirmed` trait to User factory

#### Step 2.7: Testing ✅
**Comprehensive test coverage:**
- ✅ 25 API request specs (`spec/requests/api/v1/authentication_spec.rb`)
  - Login with valid/invalid credentials
  - Email confirmation checks
  - Case-insensitive email handling
  - Signup with validation
  - Token refresh with invalidation
  - Logout with token revocation
  - All edge cases covered
- ✅ All 54 specs passing (29 auth services + 25 API requests)

**Key achievements:**
- Hybrid i18n approach: API returns error codes + English fallback, client handles translations
- Jbuilder for all JSON responses following Rails conventions
- Stateless JWT authentication ready for React Native
- Comprehensive documentation for future development

#### Step 2.8: OpenAPI/Swagger Documentation ✅ COMPLETED
**Goal:** Generate interactive API documentation accessible at `/api/docs`

**Implementation approach:**
1. ✅ Add `rswag` gem suite to Gemfile:
   - `rswag-api` - Serves Swagger UI
   - `rswag-ui` - Interactive documentation interface
   - `rswag-specs` - Generate OpenAPI specs from RSpec tests

2. ✅ Install and configure rswag:
   ```bash
   bundle install
   rails g rswag:install
   ```

3. ✅ Configure Swagger documentation (`spec/swagger_helper.rb`):
   - API metadata (title, version, description)
   - Base URL configuration
   - Authentication schemes (Bearer JWT)
   - Common response schemas
   - Error response formats

4. ✅ Document existing authentication endpoints:
   - Convert existing request specs to rswag format
   - Add parameter descriptions
   - Add response examples
   - Document error cases

5. ✅ Generate OpenAPI specification:
   ```bash
   rails rswag:specs:swaggerize
   ```

6. ✅ Mount Swagger UI in routes:
   ```ruby
   mount Rswag::Ui::Engine => '/api/docs'
   mount Rswag::Api::Engine => '/api/docs'
   ```

**Expected outcome:**
- Interactive API documentation at `https://vitt.io/api/docs`
- Auto-generated from RSpec tests (single source of truth)
- Try-it-out functionality for testing endpoints
- OAuth2/Bearer token authentication support
- Downloadable OpenAPI 3.0 JSON/YAML specification

**Files to create:**
- `spec/swagger_helper.rb` - Swagger configuration
- `spec/integration/api/v1/authentication_spec.rb` - Documented authentication specs
- `swagger/v1/swagger.yaml` - Generated OpenAPI spec

**Benefits:**
- Developers can explore and test API without Postman
- Auto-synced with actual implementation (no doc drift)
- Exportable for React Native team
- Industry-standard OpenAPI 3.0 format

---

### Phase 3: API Endpoint Creation

Create API versions of controllers following the established patterns from Phase 2. Each controller should:
- Inherit from `Api::V1::BaseController`
- Reuse existing service objects (no business logic duplication)
- Return JSON responses using Jbuilder templates
- Include comprehensive request specs

---

#### Step 3.1: Users Controller ✅ COMPLETED

**File:** `app/controllers/api/v1/users_controller.rb`

**Implemented endpoints:**
- ✅ `GET /api/v1/user` - Get current user profile
- ✅ `PATCH /api/v1/user` - Update user profile (first_name, last_name, avatar_url)

**Jbuilder templates:**
- ✅ `app/views/api/v1/users/show.json.jbuilder`
- ✅ `app/views/api/v1/users/_user.json.jbuilder` (partial for user data)

**Implemented features:**
- ✅ User model validations with URL validation for avatar_url
- ✅ Protected fields (id, email, password, created_at) cannot be updated via API
- ✅ Proper error handling with field-level validation errors
- ✅ Comprehensive test coverage (18 request specs + 5 integration specs)
- ✅ OpenAPI/Swagger documentation

**Test results:**
- ✅ 18 request specs passing
- ✅ 5 integration specs passing
- ✅ Total: 271 Swagger examples generated

---

#### Step 3.2: Dashboard Controller ✅ COMPLETED

**File:** `app/controllers/api/v1/dashboard_controller.rb`

**Endpoints implemented:**
- ✅ `GET /api/v1/dashboard` - Get dashboard overview data

**Jbuilder templates:**
- ✅ `app/views/api/v1/dashboard/show.json.jbuilder`

**Service objects reused:**
- ✅ DashboardDataService for fetching dashboard data
- ✅ MonthParameterService for parsing month parameter
- ✅ Aggregate multiple queries into single response
- ✅ Accept month filter query param

**Request specs:**
- ✅ `spec/requests/api/v1/dashboard_spec.rb`
- ✅ 14 request specs passing
- ✅ Tests complete dashboard data structure
- ✅ Tests authentication and authorization
- ✅ Tests empty data handling with default values

**Integration specs:**
- ✅ `spec/integration/api/v1/dashboard_spec.rb`
- ✅ 2 integration specs passing
- ✅ Total: 320 Swagger examples generated

**Implementation details:**
- ✅ Returns consolidated data: summary, monthly_summary, bank_accounts, recent_transactions, category_summary, spending_trends, chart_data
- ✅ Includes month filtering (defaults to current month)
- ✅ Uses Current.user pattern (set by ApiAuthenticatable)
- ✅ Consistent response structure with default values (arrays default to [], numbers to 0)
- ✅ Uses parentheses for method calls in Jbuilder
- ✅ Inherits from BaseController with JWT authentication

**Response structure:**
```json
{
  "data": {
    "balance": {
      "current": 5000.00,
      "currency": "USD"
    },
    "recent_transactions": [...],
    "upcoming_bills": [...],
    "savings_progress": {...},
    "debt_summary": {...},
    "period": {
      "start_date": "2024-01-01",
      "end_date": "2024-01-31"
    }
  }
}
```

---

#### Step 3.3: Transactions Controller

**File:** `app/controllers/api/v1/transactions_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/transactions` - List transactions with filters and pagination
- `GET /api/v1/transactions/:id` - Get single transaction
- `POST /api/v1/transactions` - Create transaction
- `PATCH /api/v1/transactions/:id` - Update transaction
- `DELETE /api/v1/transactions/:id` - Delete transaction
- `GET /api/v1/transactions/summary` - Get transaction summary/stats

**Jbuilder templates:**
- `app/views/api/v1/transactions/index.json.jbuilder`
- `app/views/api/v1/transactions/show.json.jbuilder`
- `app/views/api/v1/transactions/_transaction.json.jbuilder` (partial)

**Service objects to reuse:**
- `Transactions::CreateService`
- `Transactions::UpdateService`
- `Transactions::DeleteService`
- Existing transaction query/filter logic

**Request specs:**
- `spec/requests/api/v1/transactions_spec.rb`
- Test CRUD operations
- Test filters (date range, category, bank account, transaction type)
- Test pagination
- Test authorization (users can only access their own transactions)

**Key considerations:**
- Include related data (category, bank_account) to reduce API calls
- Support date range filters
- Return pagination metadata
- Include transaction summary/stats in list response

---

#### Step 3.4: Categories Controller

**File:** `app/controllers/api/v1/categories_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/categories` - List all categories (hierarchical)
- `GET /api/v1/categories/:id` - Get single category with transactions count
- `POST /api/v1/categories` - Create category
- `PATCH /api/v1/categories/:id` - Update category
- `DELETE /api/v1/categories/:id` - Delete category

**Jbuilder templates:**
- `app/views/api/v1/categories/index.json.jbuilder`
- `app/views/api/v1/categories/show.json.jbuilder`
- `app/views/api/v1/categories/_category.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing category model validations
- Category hierarchy logic

**Request specs:**
- `spec/requests/api/v1/categories_spec.rb`
- Test CRUD operations
- Test hierarchical category structure
- Test category with subcategories

**Key considerations:**
- Return categories in hierarchical structure (parent/child relationships)
- Include transaction count for each category
- Support both flat and nested representations
- Cache categories list (rarely changes)

---

#### Step 3.5: Bank Accounts Controller

**File:** `app/controllers/api/v1/bank_accounts_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/bank_accounts` - List all bank accounts
- `GET /api/v1/bank_accounts/:id` - Get single bank account with balance
- `POST /api/v1/bank_accounts` - Create bank account
- `PATCH /api/v1/bank_accounts/:id` - Update bank account
- `DELETE /api/v1/bank_accounts/:id` - Delete bank account

**Jbuilder templates:**
- `app/views/api/v1/bank_accounts/index.json.jbuilder`
- `app/views/api/v1/bank_accounts/show.json.jbuilder`
- `app/views/api/v1/bank_accounts/_bank_account.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing bank account model validations
- Balance calculation logic

**Request specs:**
- `spec/requests/api/v1/bank_accounts_spec.rb`
- Test CRUD operations
- Test balance calculations
- Test account with transactions

**Key considerations:**
- Include current balance in response
- Include last transaction date
- Support account type filtering (checking, savings, credit)

---

#### Step 3.6: Statement Files Controller

**File:** `app/controllers/api/v1/statement_files_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/statement_files` - List uploaded statements
- `GET /api/v1/statement_files/:id` - Get statement file status
- `POST /api/v1/statement_files` - Upload statement file
- `DELETE /api/v1/statement_files/:id` - Delete statement file
- `POST /api/v1/statement_files/:id/retry` - Retry failed processing

**Jbuilder templates:**
- `app/views/api/v1/statement_files/index.json.jbuilder`
- `app/views/api/v1/statement_files/show.json.jbuilder`
- `app/views/api/v1/statement_files/_statement_file.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing statement file upload logic
- Sidekiq job for processing

**Request specs:**
- `spec/requests/api/v1/statement_files_spec.rb`
- Test file upload (multipart form data)
- Test processing status tracking
- Test retry functionality

**Key considerations:**
- Accept multipart file uploads
- Return processing status (pending, processing, completed, failed)
- Return job ID for status tracking
- Support PDF validation
- Include processed transactions count in response

---

#### Step 3.7: Savings Controller

**File:** `app/controllers/api/v1/savings_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/savings` - List all savings goals
- `GET /api/v1/savings/:id` - Get single savings goal with progress
- `POST /api/v1/savings` - Create savings goal
- `PATCH /api/v1/savings/:id` - Update savings goal
- `DELETE /api/v1/savings/:id` - Delete savings goal
- `POST /api/v1/savings/:id/transactions` - Add contribution
- `DELETE /api/v1/savings/:id/transactions/:transaction_id` - Remove contribution

**Jbuilder templates:**
- `app/views/api/v1/savings/index.json.jbuilder`
- `app/views/api/v1/savings/show.json.jbuilder`
- `app/views/api/v1/savings/_saving.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing savings model validations
- Progress calculation logic (from Periodable concern)

**Request specs:**
- `spec/requests/api/v1/savings_spec.rb`
- Test CRUD operations
- Test contribution tracking
- Test progress calculations

**Key considerations:**
- Include progress percentage and amount
- Include monthly contribution progress
- Return projected completion date
- Include contribution history

---

#### Step 3.8: Debts Controller

**File:** `app/controllers/api/v1/debts_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/debts` - List all debts
- `GET /api/v1/debts/:id` - Get single debt with payment schedule
- `POST /api/v1/debts` - Create debt
- `PATCH /api/v1/debts/:id` - Update debt
- `DELETE /api/v1/debts/:id` - Delete debt
- `POST /api/v1/debts/:id/transactions` - Add payment
- `DELETE /api/v1/debts/:id/transactions/:transaction_id` - Remove payment

**Jbuilder templates:**
- `app/views/api/v1/debts/index.json.jbuilder`
- `app/views/api/v1/debts/show.json.jbuilder`
- `app/views/api/v1/debts/_debt.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing debt model validations
- Payment schedule calculation (from Periodable concern)

**Request specs:**
- `spec/requests/api/v1/debts_spec.rb`
- Test CRUD operations
- Test payment tracking
- Test due date calculations

**Key considerations:**
- Include payment schedule and due dates
- Include remaining balance
- Include next payment due date
- Return payment history
- Flag overdue debts

---

#### Step 3.9: Goals Controller

**File:** `app/controllers/api/v1/goals_controller.rb`

**Endpoints to implement:**
- `GET /api/v1/goals` - List all financial goals
- `GET /api/v1/goals/:id` - Get single goal with progress
- `POST /api/v1/goals` - Create goal
- `PATCH /api/v1/goals/:id` - Update goal
- `DELETE /api/v1/goals/:id` - Delete goal

**Jbuilder templates:**
- `app/views/api/v1/goals/index.json.jbuilder`
- `app/views/api/v1/goals/show.json.jbuilder`
- `app/views/api/v1/goals/_goal.json.jbuilder` (partial)

**Service objects to reuse:**
- Existing goal model validations
- Progress tracking logic

**Request specs:**
- `spec/requests/api/v1/goals_spec.rb`
- Test CRUD operations
- Test progress tracking
- Test goal completion

**Key considerations:**
- Include progress tracking
- Include achievement status
- Return target vs actual amounts
- Support different goal types

---

#### Step 3.10: Password Resets Controller ✅ COMPLETED

**File:** `app/controllers/api/v1/password_resets_controller.rb`

**Implemented endpoints:**
- ✅ `POST /api/v1/password_resets` - Request password reset (sends email)
- ✅ `PATCH /api/v1/password_resets/:token` - Reset password with token

**Jbuilder templates:**
- ✅ `app/views/api/v1/password_resets/create.json.jbuilder`
- ✅ `app/views/api/v1/password_resets/update.json.jbuilder`

**Implemented features:**
- ✅ Inherits from BaseController for error handling
- ✅ Uses `skip_before_action :authenticate_api_user!` for public access
- ✅ Security: No email enumeration (same response for existing/non-existing emails)
- ✅ Proper token validation and expiration handling
- ✅ Comprehensive error handling (INVALID_TOKEN, VALIDATION_ERROR)
- ✅ Password validation (length, confirmation match)

**Test results:**
- ✅ 13 request specs passing
- ✅ 5 integration specs passing (Swagger documentation)
- ✅ Total: 304 Swagger examples generated

---

#### Step 3.11: Email Confirmations Controller ✅ COMPLETED

**File:** `app/controllers/api/v1/email_confirmations_controller.rb`

**Implemented endpoints:**
- ✅ `POST /api/v1/email_confirmations` - Resend confirmation email
- ✅ `PATCH /api/v1/email_confirmations/:token` - Confirm email with token

**Jbuilder templates:**
- ✅ `app/views/api/v1/email_confirmations/create.json.jbuilder`
- ✅ `app/views/api/v1/email_confirmations/update.json.jbuilder`

**Implemented features:**
- ✅ Inherits from BaseController for error handling
- ✅ Uses `skip_before_action :authenticate_api_user!` for public access
- ✅ Security: No email enumeration (same response for all cases)
- ✅ Auto-login after successful confirmation (returns JWT tokens)
- ✅ Already confirmed emails handled gracefully
- ✅ Proper token validation and expiration handling

**Test results:**
- ✅ 12 request specs passing
- ✅ 4 integration specs passing (Swagger documentation)
- ✅ Auto-login feature tested and working

---

### General Guidelines for All Controllers

**For each controller implementation:**

1. **Routing:**
   - Add routes to `config/routes.rb` under `namespace :api, defaults: { format: :json }`
   - Use RESTful conventions
   - Use nested routes where appropriate (e.g., `/savings/:id/transactions`)

2. **Authentication:**
   - All endpoints require JWT authentication (inherited from BaseController)
   - Skip authentication only where explicitly needed (password reset, email confirmation)

3. **Authorization:**
   - Users can only access their own resources
   - Add authorization checks in controller actions
   - Use scoping: `current_user.transactions` not `Transaction.all`

4. **Jbuilder Templates:**
   - Follow established patterns from authentication templates
   - Use partials for reusable components
   - Include related data to reduce API calls
   - Add pagination metadata where applicable
   - Use `json.extract!` for multiple attributes

5. **Error Handling:**
   - Leverage `ApiErrorHandler` concern
   - Return appropriate HTTP status codes
   - Include error codes for client-side translation
   - Provide field-level validation errors

6. **Testing:**
   - Write comprehensive request specs for each endpoint
   - Test authentication and authorization
   - Test validation errors
   - Test edge cases
   - Aim for high test coverage

7. **Performance:**
   - Use eager loading to prevent N+1 queries
   - Implement pagination for list endpoints
   - Consider caching for frequently accessed data
   - Optimize database queries

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
