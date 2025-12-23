# API Development Guidelines

This document outlines the best practices and conventions for developing API endpoints in this application.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Authentication](#authentication)
- [Response Format](#response-format)
- [Coding Style and Conventions](#coding-style-and-conventions)
- [Jbuilder Templates](#jbuilder-templates)
- [Internationalization (i18n)](#internationalization-i18n)
- [Error Handling](#error-handling)
- [API Documentation (Swagger/OpenAPI)](#api-documentation-swaggeropenapi)
- [Testing](#testing)
- [Versioning](#versioning)

## Architecture Overview

Our API follows a namespaced structure:

```
app/controllers/api/
└── v1/
    ├── base_controller.rb        # Shared API controller logic
    ├── authentication_controller.rb
    └── [other_controllers].rb
```

### Key Principles

- **BaseController inheritance**: All API controllers inherit from `Api::V1::BaseController`, not `ActionController::API` or `ApplicationController`
- **Namespacing**: All endpoints are versioned under `/api/v1/`
- **JSON-only**: API only accepts and returns JSON
- **Stateless**: JWT-based authentication (no sessions)
- **RESTful conventions**: Follow standard REST practices where possible

### BaseController

The `Api::V1::BaseController` ([app/controllers/api/v1/base_controller.rb](app/controllers/api/v1/base_controller.rb)) is the parent class for all API controllers. It provides:

- **Authentication**: Automatically authenticates requests via `authenticate_api_user!` before action
  - Sets both `current_user` and `Current.user` automatically
- **Error handling**: Includes the `ApiErrorHandler` concern for consistent error responses
- **Helper methods**:
  - `render_error(code, message: nil, status: :unprocessable_entity, details: nil)` - Render standardized error responses
  - `format_validation_errors(errors)` - Format ActiveRecord validation errors for API responses
  - `current_user` - Access the authenticated user
  - `api_request?` - Check if request is to an API endpoint

**All API controllers must inherit from BaseController:**

```ruby
module Api
  module V1
    class MyController < BaseController
      # All actions require authentication by default

      # Skip authentication for public endpoints
      skip_before_action :authenticate_api_user!, only: [:public_action]

      def protected_action
        # current_user is available here
        # Current.user is also set automatically by ApiAuthenticatable
        # Authentication errors are handled automatically
      end

      def public_action
        # No authentication required
        # Still has access to render_error and other BaseController methods
      end

      private

      def handle_validation_failure(record)
        render_error(
          "VALIDATION_ERROR",
          message: "Failed to update record",
          status: :unprocessable_entity,
          details: format_validation_errors(record.errors)
        )
      end
    end
  end
end
```

**Why inherit from BaseController?**

✅ **DRY**: Avoid duplicating authentication and error handling code
✅ **Consistency**: All controllers use the same error format and authentication flow
✅ **Shared utilities**: Access to `render_error`, `format_validation_errors`, and other helpers
✅ **Centralized changes**: Update authentication or error handling in one place

**Example: Public endpoints (Password Reset, Email Confirmation)**

```ruby
# app/controllers/api/v1/password_resets_controller.rb
module Api
  module V1
    class PasswordResetsController < BaseController
      skip_before_action :authenticate_api_user!

      def create
        user = User.find_by(email: params[:email]&.strip&.downcase)

        if user&.can_reset_password?
          ApplicationMailer.password_reset_email(user).deliver_later
        end
        # Uses BaseController's render_error if needed
      end

      def update
        @user = User.find_by_password_reset_token!(params[:token])

        unless @user.update(password_params)
          render_error(
            "VALIDATION_ERROR",
            message: "Password reset failed",
            status: :unprocessable_entity,
            details: format_validation_errors(@user.errors)
          )
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        render_error(
          "INVALID_TOKEN",
          message: "Password reset token is invalid or has expired",
          status: :unprocessable_entity
        )
      end

      private

      def password_params
        params.require(:user).permit(:password, :password_confirmation)
      end
    end
  end
end
```

## Authentication

The API uses **JWT (JSON Web Tokens)** for authentication with the following token types:

### Token Types

- **Access Token**: Short-lived (15 minutes), used for API requests
- **Refresh Token**: Long-lived (7 days), used to obtain new access tokens

### Authentication Flow

1. **Login/Signup**: Client receives both access and refresh tokens
2. **API Requests**: Client includes access token in `Authorization` header:
   ```
   Authorization: Bearer <access_token>
   ```
3. **Token Refresh**: When access token expires, use refresh token to get new tokens
4. **Logout**: Revokes all tokens by changing the user's JTI (JWT ID)

### Protected Endpoints

All controllers inherit authentication from `BaseController`:

```ruby
module Api
  module V1
    class MyController < BaseController
      # All actions require authentication by default

      # Skip authentication for specific actions
      skip_before_action :authenticate_api_user!, only: [:public_action]
    end
  end
end
```

### Implementation Details

- **JTI-based revocation**: Each user has a unique JTI that changes on logout/token refresh
- **Token validation**: Tokens are validated for signature, expiration, and JTI match
- **Standard JWT claims**: Uses exp, iat, nbf, iss, aud for security

See [RAILWAY_JWT_SETUP.md](RAILWAY_JWT_SETUP.md) for production configuration.

## Response Format

All API responses follow a consistent JSON structure.

### Success Response

```json
{
  "data": {
    // Response payload
  },
  "message": "Optional success message",
  "meta": {
    // Optional metadata (pagination, etc.)
  }
}
```

### Error Response

```json
{
  "error": {
    "message": "Human-readable error message",
    "code": "MACHINE_READABLE_ERROR_CODE",
    "details": [
      // Optional array of validation errors or additional info
    ]
  }
}
```

## Coding Style and Conventions

### Parentheses

**Always use parentheses for method calls** in Jbuilder templates and controller code for consistency and clarity:

```ruby
# Good - with parentheses
json.id(user.id)
json.email(user.email)
json.total_balance(@total_balance)
json.bank_accounts(@dashboard_data[:bank_accounts] || [])

# Avoid - without parentheses
json.id user.id
json.email user.email
json.total_balance @total_balance
```

### Consistent Response Structure

**Always include all keys in API responses with default values** rather than conditionally rendering them. This ensures clients receive a consistent response structure:

```ruby
# Good - always returns keys with default values
json.bank_accounts(@dashboard_data[:bank_accounts] || [])
json.monthly_summary do
  monthly_summary = @dashboard_data[:monthly_summary] || {}
  json.total_income(monthly_summary[:total_income] || 0)
  json.total_expenses(monthly_summary[:total_expenses] || 0)
end

# Avoid - conditionally rendering keys
json.bank_accounts(@dashboard_data[:bank_accounts]) if @dashboard_data[:bank_accounts]
```

**Benefits:**
- ✅ Predictable response structure for clients
- ✅ Easier to consume in React Native (no undefined checks needed)
- ✅ Prevents runtime errors from missing keys
- ✅ Clear documentation (all fields always present)

**Guidelines:**
- Arrays should default to `[]` not `nil`
- Numbers should default to `0` not `nil`
- Hashes should default to `{}` not `nil`
- Strings can be `nil` if semantically appropriate

## Jbuilder Templates

We use **Jbuilder** for building JSON responses following Rails conventions.

### Directory Structure

```
app/views/api/
└── v1/
    ├── shared/
    │   └── error.json.jbuilder          # Shared error template
    └── authentication/
        ├── _user.json.jbuilder           # User partial
        ├── login.json.jbuilder
        ├── signup.json.jbuilder
        ├── refresh.json.jbuilder
        └── logout.json.jbuilder
```

### Controller Pattern

Controllers set instance variables and let Rails implicitly render the matching Jbuilder template:

```ruby
def login
  # ... authentication logic ...

  if result.success?
    @tokens = result.payload
    @user = user
    @message = "Successfully logged in"
    # Implicitly renders login.json.jbuilder
  else
    @error_message = "Login failed"
    @error_code = "TOKEN_GENERATION_FAILED"
    @error_details = result.errors.full_messages
    render("api/v1/shared/error", status: :unprocessable_entity)
  end
end
```

### Jbuilder Best Practices

**1. Always use parentheses (see [Coding Style](#coding-style-and-conventions)):**

```ruby
# Good
json.id(user.id)
json.email(user.email)

# Avoid
json.id user.id
json.email user.email
```

**2. Always include keys with default values (see [Coding Style](#coding-style-and-conventions)):**

```ruby
# Good
json.bank_accounts(@dashboard_data[:bank_accounts] || [])
json.total_income(monthly_summary[:total_income] || 0)

# Avoid
json.bank_accounts(@dashboard_data[:bank_accounts]) if @dashboard_data[:bank_accounts]
```

**3. Use `json.extract!` for multiple attributes:**

```ruby
# Good
json.extract!(user, :id, :email, :first_name, :last_name)

# Avoid
json.id(user.id)
json.email(user.email)
json.first_name(user.first_name)
json.last_name(user.last_name)
```

**4. Use partials for reusable components:**

```ruby
# app/views/api/v1/authentication/_user.json.jbuilder
json.extract!(user, :id, :email, :first_name, :last_name, :full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_url)

# In another template
json.user do
  json.partial!("api/v1/authentication/user", user: @user)
end
```

**5. Conditional attributes (only when semantically appropriate):**

```ruby
json.message(@message) if @message.present?
json.meta(@meta) if defined?(@meta) && @meta.present?
```

**6. Reuse templates with partials:**

```ruby
# signup.json.jbuilder can reuse login template
json.partial!("api/v1/authentication/login")
```

### Error Template

The shared error template ([app/views/api/v1/shared/error.json.jbuilder](app/views/api/v1/shared/error.json.jbuilder)) is used consistently across all error responses:

```ruby
# frozen_string_literal: true

json.error do
  json.message(@error_message)
  json.code(@error_code)
  json.details(@error_details || [])
end
```

Usage in controllers:

```ruby
@error_message = "Invalid credentials"
@error_code = "INVALID_CREDENTIALS"
render("api/v1/shared/error", status: :unauthorized)
```

### Implicit Rendering

Rails automatically renders the Jbuilder template matching the action name:

```ruby
# In LoginController#create
def create
  @user = User.find(params[:id])
  # Automatically renders app/views/login/create.json.jbuilder
end

# Override status code when needed
def signup
  @user = User.create(signup_params)
  @message = "Account created"
  render(status: :created)  # Still renders signup.json.jbuilder
end
```

## Internationalization (i18n)

We use a **hybrid internationalization approach**:

### API Responsibility (Server-Side)

- Return **error codes** for all errors (e.g., `INVALID_CREDENTIALS`, `EMAIL_NOT_CONFIRMED`)
- Return **English fallback messages** for human readability during development
- Keep error codes consistent and well-documented

### Client Responsibility (React Native)

- Handle translation of error codes to user's locale
- Use error codes to map to localized strings
- Fall back to English message if translation unavailable

### Example

**Server response:**
```json
{
  "error": {
    "message": "Invalid email or password",
    "code": "INVALID_CREDENTIALS"
  }
}
```

**React Native implementation:**
```javascript
const errorMessages = {
  en: {
    INVALID_CREDENTIALS: "Invalid email or password",
    EMAIL_NOT_CONFIRMED: "Please confirm your email"
  },
  es: {
    INVALID_CREDENTIALS: "Correo o contraseña inválidos",
    EMAIL_NOT_CONFIRMED: "Por favor confirma tu correo"
  }
};

// Use error.code to get localized message
const localizedMessage = errorMessages[userLocale][error.code] || error.message;
```

### Benefits

✅ Works offline (translations bundled with app)
✅ Faster response times (no server-side locale detection)
✅ Better mobile UX (instant language switching)
✅ Simpler API (no locale parameter needed)
✅ Easier testing (consistent error codes)

### Error Code Conventions

- Use **SCREAMING_SNAKE_CASE** for error codes
- Be descriptive but concise: `EMAIL_NOT_CONFIRMED` not `ERR_001`
- Group related errors with prefixes: `VALIDATION_`, `AUTH_`, etc.
- Document all error codes in API documentation

## Error Handling

Errors are handled consistently through the `ApiErrorHandler` concern.

### Automatic Error Handling

These errors are automatically caught and formatted:

- `ActiveRecord::RecordNotFound` → 404 Not Found
- `ActiveRecord::RecordInvalid` → 422 Unprocessable Entity
- `ActionController::ParameterMissing` → 400 Bad Request
- `StandardError` → 500 Internal Server Error (production only)

### Validation Errors

Validation errors are automatically formatted with field-level details:

```json
{
  "error": {
    "message": "Failed to create account",
    "code": "VALIDATION_ERROR",
    "details": [
      {
        "field": "email",
        "message": "has already been taken",
        "code": "taken"
      },
      {
        "field": "password",
        "message": "is too short",
        "code": "too_short"
      }
    ]
  }
}
```

### Custom Errors

For custom error handling, use the `render_error` helper:

```ruby
def create
  if some_custom_validation_fails
    return render_error("CUSTOM_ERROR_CODE",
      message: "Custom error message",  # Optional - auto-generated from code if not provided
      status: :unprocessable_entity)    # Optional - defaults to :unprocessable_entity
  end

  # ... continue
end
```

**Key Features:**
- **Code-first approach**: Error code is the primary required parameter
- **Auto-generated messages**: If message is not provided, it's automatically generated from the code
  - `"INVALID_CREDENTIALS"` → `"Invalid credentials"`
  - `"EMAIL_NOT_CONFIRMED"` → `"Email not confirmed"`
- **Default status**: Defaults to `:unprocessable_entity` if not specified
- **Optional details**: Include validation errors or additional context with `details:` parameter

**Usage Examples:**

```ruby
# Minimal - message auto-generated
render_error("INVALID_CREDENTIALS", status: :unauthorized)
# => { error: { message: "Invalid credentials", code: "INVALID_CREDENTIALS" } }

# With custom message
render_error("INVALID_CREDENTIALS",
  message: "Wrong email or password",
  status: :unauthorized)

# With validation details
render_error("VALIDATION_ERROR",
  message: "Failed to create account",
  details: format_validation_errors(user.errors))
```

## API Documentation (Swagger/OpenAPI)

We use **rswag** to auto-generate interactive API documentation from RSpec integration tests. This ensures our documentation stays in sync with the actual implementation.

### Accessing Documentation

- **Local development**: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)
- **Production**: [https://vitt.io/api/docs](https://vitt.io/api/docs)

The Swagger UI provides:
- Interactive API explorer with "Try it out" functionality
- Request/response examples for all endpoints
- Authentication support (JWT Bearer tokens)
- Downloadable OpenAPI 3.0 specification (YAML/JSON)

### How It Works

Documentation is generated from integration tests located in `spec/integration/api/v1/`:

```ruby
# spec/integration/api/v1/authentication_spec.rb
require "swagger_helper"

RSpec.describe "API V1 Authentication", type: :request do
  path "/api/v1/login" do
    post "Authenticate user and get tokens" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      description "Login with email and password to receive JWT tokens"

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password }
            },
            required: [:email, :password]
          }
        }
      }

      response "200", "Login successful" do
        schema "$ref" => "#/components/schemas/AuthenticationResponse"

        let(:credentials) { { user: { email: "user@example.com", password: "password123" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["access_token"]).to be_present
        end
      end
    end
  end
end
```

### Generating Documentation

After adding or modifying integration tests, regenerate the OpenAPI spec:

```bash
# Generate swagger.yaml from integration tests
RAILS_ENV=test rails rswag:specs:swaggerize
```

This creates/updates `swagger/v1/swagger.yaml` which is automatically served by the Swagger UI.

### Configuration

**Swagger schemas and metadata**: [spec/swagger_helper.rb](spec/swagger_helper.rb)

Defines:
- API metadata (title, version, description)
- Server URLs (production, development)
- Authentication schemes (Bearer JWT)
- Reusable schemas (User, Error, AuthenticationResponse, etc.)

**Swagger UI config**: [config/initializers/rswag_ui.rb](config/initializers/rswag_ui.rb)

**Swagger API config**: [config/initializers/rswag_api.rb](config/initializers/rswag_api.rb)

### Directory Structure

Integration tests should be organized by resource in separate directories, with one file per endpoint:

```
spec/integration/api/v1/
├── categories/
│   ├── index_spec.rb       # GET /api/v1/categories
│   ├── show_spec.rb        # GET /api/v1/categories/:id
│   ├── create_spec.rb      # POST /api/v1/categories
│   ├── update_spec.rb      # PATCH /api/v1/categories/:id
│   └── destroy_spec.rb     # DELETE /api/v1/categories/:id
├── transactions/
│   ├── index_spec.rb
│   ├── show_spec.rb
│   ├── create_spec.rb
│   ├── update_spec.rb
│   ├── destroy_spec.rb
│   └── summary_spec.rb
└── authentication_spec.rb  # Simple resources can use single file
```

**Benefits:**
- ✅ Easier to find and maintain endpoint-specific tests
- ✅ Clearer git history (changes to one endpoint don't affect others)
- ✅ Parallel test execution potential
- ✅ Matches request specs structure for consistency

### Schema Organization

Schemas are organized in JSON files for easy maintenance:

```
spec/integration/support/
├── response_body/
│   ├── error.json                    # Shared across all versions
│   ├── validation_error.json         # Shared across all versions
│   └── v1/
│       ├── user.json
│       ├── category.json
│       ├── categories_list.json
│       └── category_single.json
└── parameters/
    └── v1/
        └── [parameter schemas]
```

**Schema Naming Convention:**
- Root files: `error.json` → `error_response`
- Versioned files: `v1/category.json` → `v1_category_response`
- Parameter files: `v1/user.json` → `v1_user_params`

The `swagger_helper.rb` automatically loads these schemas and generates the appropriate names.

### Writing Documented Tests

#### 1. Create integration test file

```bash
# Create directory for the resource
mkdir -p spec/integration/api/v1/categories

# Create file for specific endpoint
touch spec/integration/api/v1/categories/index_spec.rb
```

#### 2. Use rswag DSL to document endpoints

```ruby
require "swagger_helper"

RSpec.describe "API V1 Resources", type: :request do
  path "/api/v1/resources" do
    get "List all resources" do
      tags "Resources"
      produces "application/json"
      security [Bearer: []]  # Requires authentication

      parameter name: :page, in: :query, type: :integer, required: false,
                description: "Page number (default: 1)"
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: "Items per page (default: 20)"

      response "200", "Resources retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { "$ref" => "#/components/schemas/Resource" }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     page: { type: :integer },
                     per_page: { type: :integer },
                     total: { type: :integer }
                   }
                 }
               }

        let!(:user) { create(:user) }
        let(:Authorization) { "Bearer #{generate_token(user)}" }

        run_test!
      end

      response "401", "Unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
```

#### 3. Define reusable schemas as JSON files

Create schema files in `spec/integration/support/response_body/`:

```bash
# Create a response schema
touch spec/integration/support/response_body/v1/resource.json
```

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "integer",
      "description": "Resource ID"
    },
    "name": {
      "type": "string",
      "description": "Resource name"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "Creation timestamp"
    }
  },
  "required": ["id", "name"]
}
```

The `swagger_helper.rb` will automatically load this file and make it available as `v1_resource_response` in your specs:

```ruby
response "200", "Resource retrieved" do
  schema "$ref" => "#/components/schemas/v1_resource_response"
  # ...
end
```

### Best Practices

**1. Single source of truth:**
- Integration tests serve as both tests AND documentation
- Ensures docs never drift from implementation
- Tests validate that documented responses actually work

**2. Comprehensive response coverage:**
- Document all possible response codes (200, 401, 403, 404, 422, 500)
- Include examples for each response type
- Test error cases, not just happy paths

**3. Use schema references:**
- Define common schemas in `swagger_helper.rb`
- Reference with `"$ref" => "#/components/schemas/User"`
- Keeps documentation DRY and consistent

**4. Authentication:**
- Mark protected endpoints with `security [Bearer: []]`
- Test both authenticated and unauthenticated cases

**5. Descriptive metadata:**
- Add clear `description` text for endpoints and parameters
- Use semantic `tags` to group related endpoints
- Specify `format` hints (email, date-time, uri, etc.)

### Workflow

1. **Write integration test** with rswag DSL
2. **Run test** to verify it passes: `rspec spec/integration/api/v1/my_resource_spec.rb`
3. **Generate docs**: `RAILS_ENV=test rails rswag:specs:swaggerize`
4. **View in browser**: Visit `/api/docs` to see interactive documentation
5. **Commit** both test file and generated `swagger/v1/swagger.yaml`

### Benefits

✅ Always up-to-date (generated from tests)
✅ Interactive testing via Swagger UI
✅ Exportable for React Native team
✅ Industry-standard OpenAPI 3.0 format
✅ Single source of truth (no doc drift)
✅ Validates documented behavior actually works

## Testing

### Running Tests

Use `bundle exec rspec` to run tests:

```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/requests/api/v1/categories/index_spec.rb

# Run all tests for a resource
bundle exec rspec spec/requests/api/v1/categories/

# Generate Swagger docs from integration tests
RAILS_ENV=test bundle exec rails rswag:specs:swaggerize
```

### Request Specs Organization

Request specs test API functionality without generating documentation. Organize by resource with one file per endpoint:

```
spec/requests/api/v1/
├── categories/
│   ├── index_spec.rb       # GET /api/v1/categories
│   ├── show_spec.rb        # GET /api/v1/categories/:id
│   ├── create_spec.rb      # POST /api/v1/categories
│   ├── update_spec.rb      # PATCH /api/v1/categories/:id
│   └── destroy_spec.rb     # DELETE /api/v1/categories/:id
├── transactions/
│   ├── index_spec.rb
│   ├── show_spec.rb
│   ├── create_spec.rb
│   ├── update_spec.rb
│   └── destroy_spec.rb
└── authentication_spec.rb  # Simple resources can use single file
```

**Benefits:**
- ✅ Easier to find and maintain tests for specific endpoints
- ✅ Clearer git history
- ✅ Matches integration specs structure
- ✅ Faster test execution (can run specific endpoints)

### Request Spec Example

```ruby
# spec/requests/api/v1/categories/index_spec.rb
require "rails_helper"

RSpec.describe "Api::V1::Categories - Index", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/categories" do
    it "returns all categories in hierarchical structure" do
      category = create(:category, user: user, name: "Food")
      subcategory = create(:category, user: user, name: "Groceries", parent: category)

      get "/api/v1/categories", headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json["data"]["categories"]).to be_an(Array)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/categories"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

### Test Coverage Requirements

Ensure coverage for:
- ✅ Successful requests (happy path)
- ✅ Authentication failures (401)
- ✅ Validation errors (422)
- ✅ Authorization checks
- ✅ Not found errors (404)
- ✅ Correct error codes

## Versioning

API versioning is done via URL namespacing: `/api/v1/`, `/api/v2/`, etc.

### Creating a New Version

When breaking changes are needed:

1. Create new namespace: `app/controllers/api/v2/`
2. Copy and modify controllers as needed
3. Update routes:
   ```ruby
   namespace :api do
     namespace :v1 do
       # existing routes
     end

     namespace :v2 do
       # new routes
     end
   end
   ```
4. Maintain v1 for backwards compatibility
5. Document deprecation timeline

### Best Practices

- Avoid breaking changes in existing versions
- Add new fields instead of changing existing ones
- Use optional parameters for new features
- Communicate deprecation well in advance

## Additional Resources

- [RAILWAY_JWT_SETUP.md](RAILWAY_JWT_SETUP.md) - Production JWT configuration
- [DEVELOPMENT.md](DEVELOPMENT.md) - General development guidelines
- [API_CONVERSION_PLAN.md](API_CONVERSION_PLAN.md) - API implementation roadmap
