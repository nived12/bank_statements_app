# Development Guide

## Project Overview

This is a **Budgeting and Personal Finance Management Application** that helps users take control of their financial lives. The application allows users to upload bank statements, automatically categorize transactions, view comprehensive financial reports, set budgets, and track financial goals.

### Core Features
- Bank statement upload and processing
- Automatic transaction categorization
- Transaction matching (statement vs manual entry) to prevent duplicates
- Financial statements and reports
- Planned: Budget management and spending tracking
- Planned: Financial goal setting and progress tracking
- Planned: AI financial coach with personalized advice
- Planned: Multi-tenant support for organizations managing user finances

### Target Users
- **Primary**: Individuals managing personal finances
- **Future**: Organizations managing finances for their users

## Tech Stack

### Backend
- **Ruby**: 3.3.0
- **Rails**: 8.x
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq
- **Authentication**: Devise
- **Cache/Queue**: Redis

### Frontend
- **Styling**: Tailwind CSS
- **Interactivity**: Hotwire (Turbo Frames, Turbo Streams, Stimulus)
- **Rendering**: Server-side with Hotwire enhancement
- **Mobile**: Hotwire Native (iOS & Android - planned)

### Future Considerations
- REST API endpoints (planned)
- AI integration for financial coaching

## Code Architecture

### Service Objects
We use service objects for business logic following these patterns:

```ruby
# Base class for all services
class ApplicationService
  def self.call(...)
    new(...).call
  end
end

# Example usage
class Transactions::CreateService < ApplicationService
  include Transactions::Concerns::Transferable

  def initialize(transaction_params)
    super()
    @transaction_params = transaction_params
  end

  def call
    # Business logic here
    success(transaction)
  end
end
```

**Service Object Guidelines:**
- One public method: `call`
- Use class method `self.call` for convenience
- Use concerns to share functionality across services
- Keep services focused on a single responsibility
- Return meaningful results (success/failure objects or domain objects)

### Background Jobs
- Use Sidekiq for all asynchronous processing
- Examples: statement parsing, transaction categorization, report generation
- Always consider job idempotency

### Model Organization
- **Fat models, skinny controllers** principle
- Use concerns for shared behavior across models
- Keep business logic in service objects, not models
- Models should handle data integrity and simple queries

## Frontend Patterns

### Design Requirements
- **Always use modern, contemporary design patterns** for all UI elements
- Follow current design trends and best practices (2024+ standards)
- Ensure interfaces feel fresh, clean, and up-to-date
- Avoid outdated UI patterns, colors, layouts, or interaction styles
- Use modern spacing, typography, and color schemes
- Implement current accessibility standards and inclusive design

### Hotwire/Turbo Usage

**Turbo Frames:**
- Used for modals and dialogs
- Used for inline editing interfaces
- Keeps page sections independently updateable

**Turbo Streams:**
- Used for real-time UI updates without page reload
- Used for form submissions with targeted updates
- Handles create, update, delete operations

**Stimulus Controllers:**
- Keep controllers small and focused
- One controller per behavior/feature
- Use actions, targets, and values appropriately
- Prefer server-side logic over complex client-side code

### Tailwind CSS
- Use utility classes exclusively
- Avoid custom CSS unless absolutely necessary
- Follow mobile-first responsive design
- Use Tailwind's configuration for theme consistency
- **Always use modern, contemporary design patterns** - Ensure all UI elements follow current design trends and avoid outdated styles

### Mobile (Hotwire Native)
- Ensure all Turbo Frame interactions work on mobile
- Test navigation flows on iOS and Android simulators
- Consider touch targets and mobile UX patterns

## Testing Philosophy

### Framework & Tools
- **Primary**: RSpec for all testing
- **Coverage**: Aim for comprehensive test coverage
- **Philosophy**: Test-Driven Development (TDD) when possible

### Testing Rules
✅ **DO:**
- Write tests for every change, no matter how small
- Run tests after every change
- **ALWAYS ensure specs pass after implementation** - Never consider a task complete until all tests pass
- Test both happy paths and edge cases
- Use specs to test delete operations (never delete in development)
- Follow RSpec best practices (let, let!, subject, contexts)

❌ **DON'T:**
- Skip tests for "small" changes
- Commit code without passing tests
- Consider implementation complete without passing specs
- Test implementation details; test behavior

### Test Structure
```ruby
RSpec.describe Transactions::MatchStatementToManual do
  describe '#call' do
    context 'when matching transaction exists' do
      it 'links statement to manual transaction' do
        # test implementation
      end
    end

    context 'when no matching transaction exists' do
      it 'creates a new transaction' do
        # test implementation
      end
    end
  end
end
```

### JavaScript/Stimulus Testing
- **Stimulus controllers do NOT require tests** due to configuration complexity
- Focus testing on server-side logic (models, services, controllers, requests)
- Stimulus controllers should be kept simple and follow established patterns
- Complex logic should be in services/models where it can be easily tested
- Manual browser testing is sufficient for Stimulus controller verification

## Code Standards & Principles

### Non-Negotiable Rules

1. **NEVER run production commands without explicit user approval**
   - Never use `RAILS_ENV=production` in any command
   - Never run `rails assets:precompile` with production environment
   - Never run deployment scripts or production migrations
   - Never run any command that could affect production data or environment
   - If testing production behavior, use a staging environment instead
   - Always ask the user before running any command that touches production

2. **Never delete records from the database when testing**
   - Never delete records using rails runner or rails console for testing purposes
   - Deletion in application code (controllers, services) is allowed for legitimate features
   - Always test deletion operations in RSpec specs, never manually
   - If you need to verify deletion works, write a proper spec

3. **Always add specs for new features**
   - No feature without corresponding tests
   - Update tests when modifying features

4. **Follow existing patterns**
   - Study the codebase before adding new patterns
   - Be consistent with established conventions

5. **Clean up after yourself**
   - Remove unused code when adding new code
   - Refactor as you go
   - Leave code cleaner than you found it

6. **Always use translations**
   - Always set Spanish and English translations for all user-facing text
   - Use `config/locales/en.yml` and `config/locales/es.yml`
   - Structure translations hierarchically using sections and subsections
   - Never hardcode user-facing text in views, controllers, or services

### Design Principles

- **DRY (Don't Repeat Yourself)**: Extract common logic into shared methods/services
- **SOLID Principles**: Especially Single Responsibility and Dependency Inversion when possible
- **RESTful Routes**: Follow Rails conventions for routing
- **Convention over Configuration**: Use Rails defaults unless you have a good reason not to
- **Ruby Style**: Always use double quotes for strings instead of single quotes

### Best Practices by Technology

**Rails:**
- Follow Rails 8 conventions and best practices
- Use strong parameters in controllers
- Leverage ActiveRecord efficiently (avoid N+1 queries)
- Use database constraints and validations
- **Always store dates/times in UTC** - Never store local time in the database
- **Display dates/times in user's local timezone** - Convert UTC to local time for display

**Sidekiq:**
- Make jobs idempotent
- Handle failures gracefully
- Use appropriate queues and priorities
- Monitor job performance

**PostgreSQL:**
- Use migrations for all schema changes
- Add indexes for frequently queried columns
- Use database constraints for data integrity
- Leverage PostgreSQL features (JSONB, full-text search, etc.)
- **Always store dates/times in UTC** - Never store local time in the database
- **Display dates/times in user's local timezone** - Convert UTC to local time for display

**Devise:**
- Customize views to match application design
- Use Devise helpers and callbacks
- Don't fight the framework; extend thoughtfully

**Date/Time Handling:**
- **Always store dates/times in UTC** - Never store local time in the database
- **Display dates/times in user's local timezone** - Convert UTC to local time for display
- Use `Time.zone` for timezone-aware operations
- Use `Time.current` instead of `Time.now` for consistency
- Store user timezone preferences and apply them for display
- Use Rails time helpers (`time_ago_in_words`, `distance_of_time_in_words`) for user-friendly display

**Internationalization (i18n):**
- **Always use translations** - Never hardcode user-facing text
- Maintain both English and Spanish translations in sync
- Structure translations hierarchically by feature/section:
  ```yaml
  # config/locales/en.yml
  en:
    mobile:
      dashboard:
        title: "Dashboard"
        subtitle: "Your financial overview"
        balance: "Current Balance"
  ```
- Access translations using dot notation:
  - In views: `<%= t('mobile.dashboard.title') %>`
  - In controllers/services: `I18n.t('mobile.dashboard.title')`
  - With interpolation: `t('mobile.dashboard.welcome', name: @user.name)`
- Organization pattern: `[section].[feature].[element]`
  - Example: `transactions.index.title`, `budgets.form.submit_button`
- Keep keys descriptive and consistent across locales
- Test both English and Spanish versions of your features

**JSON Rendering (Jbuilder):**
- **ALWAYS use Jbuilder** for JSON responses - never render JSON inline in controllers
- Create dedicated `.json.jbuilder` view files in `app/views/[controller]/`
- Benefits:
  - Separation of concerns (JSON structure in view layer)
  - Easier to maintain and modify
  - Testable independently from controllers
  - Reusable with partials
  - Follows Rails conventions
- Example structure:
  ```ruby
  # app/controllers/categories_controller.rb
  def index
    @categories = current_user.categories.order(:name)

    respond_to do |format|
      format.html
      format.json  # Automatically renders index.json.jbuilder
    end
  end
  ```
  ```ruby
  # app/views/categories/index.json.jbuilder
  json.array! @categories do |category|
    json.id category.id
    json.name category.name
    json.parent_id category.parent_id
    json.icon category.icon
  end
  ```
- Use partials for shared JSON structures:
  ```ruby
  # app/views/categories/_category.json.jbuilder
  json.extract! category, :id, :name, :parent_id, :icon

  # app/views/categories/index.json.jbuilder
  json.array! @categories, partial: 'categories/category', as: :category
  ```

## Development Workflow

1. **Before starting:**
   - Pull latest changes from main (if there is any change without commit)
   - Review related code and tests
   - Plan your approach

2. **During development:**
   - Write/update tests first (TDD)
   - Implement feature following existing patterns
   - Run tests frequently
   - **ALWAYS ensure specs pass after implementation** - This is non-negotiable
   - Clean up unused code

3. **Before committing:**
   - Run full test suite from the changed files
   - **ALWAYS ensure all specs pass before committing** - This is non-negotiable
   - Check for code quality issues
   - Remove debugging code
   - Ensure all new code has tests

4. **Code review checklist:**
   - Tests are comprehensive
   - Follows existing patterns
   - No unused code left behind
   - Documentation updated if needed

## Common Patterns

### Creating a new feature
1. Add route (RESTful when possible)
2. Create controller action
3. Create/update service object for business logic
4. Add Turbo Frame/Stream for dynamic behavior
5. Style with Tailwind CSS
6. Add Stimulus controller if needed for client-side behavior
7. Write comprehensive specs

### Handling file uploads (bank statements)
1. Accept file upload in controller
2. Queue Sidekiq job for processing
3. Parse file in background
4. Match transactions to prevent duplicates
5. Update UI with Turbo Stream
6. Handle errors gracefully

## Getting Help

- Check existing code for similar patterns
- Review service objects in `app/services/`
- Look at test examples in `spec/`
- Consult Rails 8 and Hotwire documentation
- Any new patter we discuss that we agree on, lets add it to this file to update the context of the project

## Future Roadmap

- [ ] Budget planner feature
- [ ] AI financial coach integration
- [ ] Multi-tenant organization support
- [ ] REST API for third-party integrations
- [ ] Advanced financial analytics and predictions
- [ ] Native mobile apps (iOS & Android)
