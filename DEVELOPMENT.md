# Development Guide

## Project Overview

**Budgeting and Personal Finance Management Application**: bank statement upload/processing, automatic categorization, transaction matching (prevent duplicates), financial reports, goals/savings/debts, recurring series, subscriptions, and the Vittbot assistant. Planned: budgets, multi-tenant.

**Users:** Individuals (primary); organizations (future).

## Tech Stack

- **Backend:** Ruby 3.3.0, Rails 8.x, PostgreSQL, Sidekiq + Redis, `has_secure_password` with Google OAuth for the web, JWT for the API
- **Frontend:** Tailwind CSS, Hotwire (Turbo Frames/Streams, Stimulus), server-side rendering; React Native + Expo for mobile (REST API)
- **AI:** Google Gemini (`AI_PROVIDER=gemini` by default) for statement, receipt and voice parsing and assistant turns; Ghostscript renders scanned PDFs for Gemini Vision; OpenAI optional via `AI_PROVIDER=openai`
- **Payments:** `pay` + Stripe on the web, RevenueCat webhook for App Store subscriptions
- **API:** See [API_DEVELOPMENT.md](API_DEVELOPMENT.md)

## Code Architecture

### Service Objects

- Base: `ApplicationService` with `self.call(...)` → `new(...).call`
- One public method: `call`; use concerns for shared logic; single responsibility
- **Naming:** No `-Service` suffix. Use namespaced `-er` nouns: `Dashboard::DataFetcher`, `Goals::Creator`, `Transactions::Importer`. Generic utilities un-namespaced: `ErrorHandler`, `ApplicationService`

### Background Jobs

- Sidekiq for async work; make jobs idempotent; handle failures
- Scheduled jobs live in `config/schedule.yml` (`sidekiq-cron`), loaded by `config/initializers/sidekiq.rb`. A job that is not listed there never runs, and no unit test can see that, so assert the wiring

### Models

- Fat models, skinny controllers; concerns for shared behavior; business logic in services; models = data integrity + simple queries

## Frontend

- **Design:** Modern, contemporary UI; 2024+ standards; avoid outdated patterns
- **Turbo Frames:** Modals, dialogs, inline editing
- **Turbo Streams:** Real-time updates, form submissions, CRUD
- **Stimulus:** Small, focused controllers; one per behavior; register in `app/javascript/controllers/index.js` (or run `./bin/rails stimulus:manifest:update`)
- **Tailwind:** Utility classes only; mobile-first; no custom CSS unless necessary

## Testing

- **RSpec** for all changes; TDD when possible; **specs must pass before task is complete**
- Test happy paths and edge cases; request specs in `spec/requests`; use specs for delete operations (never delete in dev)
- **Stimulus:** No tests required; keep logic in services/models; manual browser check is enough
- **Playwright:** Any new UI behavior or behavior change must include added/updated Playwright tests (see [e2e/README.md](e2e/README.md))
- **Running:** `bundle exec rspec <file>` while working; `bin/ci-test` for the full suite in parallel
- **Speed:** Aim for fast specs (~1s max per spec)

## Non-Negotiable Rules

1. **Production:** Never run production commands without explicit approval; no `RAILS_ENV=production`, no production migrations/deploys
2. **Deletions:** Test deletions in specs only; never delete in console/runner
3. **Specs:** Every feature has tests; update tests when changing features
4. **Patterns:** Follow existing patterns; study codebase first
5. **Cleanup:** Remove unused code; leave code cleaner
6. **i18n:** All user-facing text via `config/locales/en.yml` and `es.yml`; hierarchical keys (`[section].[feature].[element]`); never hardcode
7. **Dates:** Store UTC; display in user timezone; use `Time.zone`, `Time.current`; see Rails time helpers for display

## Standards

- **Ruby:** Double quotes; Rails 8 conventions; strong params; avoid N+1; DB constraints/validations
- **Sidekiq:** Idempotent jobs; appropriate queues
- **PostgreSQL:** Migrations for schema; indexes; constraints; schema annotations via `rake schema:annotate`
- **JSON API:** Jbuilder only (no inline JSON in controllers); `.json.jbuilder` in `app/views/[controller]/`; test in request specs
- **DRY/SOLID:** RESTful routes; convention over configuration

## Workflow

1. **Before:** Pull latest; review code/tests; plan
2. **During:** Tests first → implement → run tests → cleanup
3. **Before commit:** Full test suite on changed files; no debug code; all new code tested
4. **Review:** Comprehensive tests; consistent patterns; no dead code; docs updated if needed

## Common Patterns

**New feature:** Route → controller → service → Turbo/Stimulus if needed → Tailwind → specs

**File upload (statements):** Controller accepts file → queue Sidekiq job → parse in background → match transactions → Turbo Stream update → handle errors

## Authorization

**Pundit** deferred until enterprise/org permissions. Until then, authorization in controllers (e.g. `check_subscription_access!` for statement uploads).

## Period-Based Goals (Debts & Savings)

- **Debts:** `due_day_of_month`, `payment_frequency`, `target_payment_amount`; `calculate_next_due_date`, `payment_due_in_days`, `payment_overdue?`
- **Savings:** `target_contribution_amount`, `contribution_frequency`, `contribution_mode` (nil / "fixed" / "calculated"); `calculated_monthly_contribution`, `behind_this_month?`, `current_month_progress`
- **Periodable concern:** `progress_for_period`, `current_month_progress`, `monthly_timeline`
- **Reminders:** Implemented but disabled until User Notification Preferences exist. Built: `Reminders::GenerateRemindersService`, `GenerateRemindersJob`, `ReminderMailer`. The job is deliberately absent from `config/schedule.yml`: the service persists nothing and its mailer calls are commented out, so a scheduled run would compute reminders and throw them away. To enable: add notification preferences, gate the mailer by preferences, add a `schedule.yml` entry, add mailer specs.

## Future Roadmap

- Budget planner; User Notification Preferences (for reminders); Pundit (org permissions); multi-tenant; deeper analytics

Already shipped, do not re-plan these: the REST API (`app/controllers/api/v1/`), the Vittbot assistant (`app/services/assistant/`), goals/savings/debts, recurring series, subscriptions, and the React Native mobile app.

## Getting Help

- Check `app/services/`, `spec/`; Rails 8 & Hotwire docs; document new patterns here
