# API Development Guidelines

This document outlines the best practices and conventions for developing API endpoints in this application.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Authentication](#authentication)
- [Response Format](#response-format)
- [Jbuilder Templates](#jbuilder-templates)
- [Internationalization (i18n)](#internationalization-i18n)
- [Error Handling](#error-handling)
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

- **API-only controllers**: All API controllers inherit from `ActionController::API`, not `ApplicationController`
- **Namespacing**: All endpoints are versioned under `/api/v1/`
- **JSON-only**: API only accepts and returns JSON
- **Stateless**: JWT-based authentication (no sessions)
- **RESTful conventions**: Follow standard REST practices where possible

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

Controllers automatically authenticate requests via the `ApiAuthenticatable` concern:

```ruby
class MyController < Api::V1::BaseController
  # All actions require authentication by default

  # Skip authentication for specific actions
  skip_before_action :authenticate_api_user!, only: [:public_action]
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

**1. Use `json.extract!` for multiple attributes:**

```ruby
# Good
json.extract! user, :id, :email, :first_name, :last_name

# Avoid
json.id user.id
json.email user.email
json.first_name user.first_name
json.last_name user.last_name
```

**2. Use partials for reusable components:**

```ruby
# app/views/api/v1/authentication/_user.json.jbuilder
json.extract! user, :id, :email, :first_name, :last_name, :full_name
json.confirmed user.confirmed?
json.avatar_url user.avatar_url

# In another template
json.user do
  json.partial! "api/v1/authentication/user", user: @user
end
```

**3. Conditional attributes:**

```ruby
json.message @message if @message.present?
json.meta @meta if defined?(@meta) && @meta.present?
```

**4. Reuse templates with partials:**

```ruby
# signup.json.jbuilder can reuse login template
json.partial! "api/v1/authentication/login"
```

### Error Template

The shared error template ([app/views/api/v1/shared/error.json.jbuilder](app/views/api/v1/shared/error.json.jbuilder)) is used consistently across all error responses:

```ruby
# frozen_string_literal: true

json.error do
  json.message @error_message
  json.code @error_code
  json.details @error_details if @error_details.present?
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

## Testing

### Request Specs

All API endpoints should have comprehensive request specs:

```ruby
# spec/requests/api/v1/authentication_spec.rb
require 'rails_helper'

RSpec.describe "Api::V1::Authentication", type: :request do
  describe "POST /api/v1/login" do
    context "with valid credentials" do
      it "returns tokens and user data" do
        user = create(:user, :confirmed)

        post "/api/v1/login", params: {
          user: { email: user.email, password: "password" }
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]).to include("access_token", "refresh_token")
        expect(json["data"]["user"]["id"]).to eq(user.id)
      end
    end

    context "with invalid credentials" do
      it "returns error with code" do
        post "/api/v1/login", params: {
          user: { email: "invalid@example.com", password: "wrong" }
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_CREDENTIALS")
        expect(json["error"]["message"]).to be_present
      end
    end
  end
end
```

### Test Coverage

Ensure coverage for:
- ✅ Successful requests (happy path)
- ✅ Authentication failures
- ✅ Validation errors
- ✅ Authorization (correct user can access, others cannot)
- ✅ Edge cases (missing params, invalid formats, etc.)
- ✅ Error codes are correct and consistent

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
