# Vittio — Claude Code Context

Personal finance app: bank statement upload, AI-powered parsing, transaction categorization, duplicate matching, financial goals. Built with Rails 8.

Full guidelines: `DEVELOPMENT.md`

## Stack

- **Backend:** Ruby 3.3.0, Rails 8.x, PostgreSQL, Sidekiq, Devise, Redis
- **Frontend:** Tailwind CSS, Hotwire (Turbo Frames/Streams, Stimulus), server-side rendering
- **AI:** OpenAI GPT for statement parsing; Tesseract OCR fallback
- **Mobile (planned):** Hotwire Native (iOS & Android)

## Non-Negotiable Rules

1. **Never run production commands** without explicit approval — no `RAILS_ENV=production`, no deploys
2. **Never delete records** via rails runner/console — deletions go in RSpec specs only
3. **Specs must pass** before any task is considered complete — TDD when possible
4. **All user-facing text** via i18n (`config/locales/en.yml` + `es.yml`) — never hardcode
5. **Always use Jbuilder** for JSON — never inline JSON in controllers
6. **Remove unused code** as you go — leave the codebase cleaner
7. **Double quotes** for all Ruby strings

## Architecture Patterns

### Service Objects
```ruby
class Namespace::DoerName < ApplicationService
  def initialize(params) = @params = params

  def call
    # single responsibility
    success(result)
  end
end
# Usage: Namespace::DoerName.call(params)
```
- Naming: namespaced `-er` nouns (`Transactions::Importer`, `Goals::Creator`)
- No `-Service` suffix
- One public method: `call`

### Frontend
- Turbo Frames → modals, inline editing
- Turbo Streams → real-time CRUD updates
- Stimulus → small, focused, one controller per behavior
- Tailwind utilities only — no custom CSS unless unavoidable
- Mobile-first, modern design (2024+ patterns)

### Database / Dates
- Migrations for all schema changes; add indexes; use DB constraints
- **Store UTC always** — display in user's timezone using `Time.zone` / `Time.current`
- **String enums** — always use `string` columns for enums, never integers (e.g. `t.string :match_type, null: false, default: "contains"`)

### i18n
- Keys: `[section].[feature].[element]` — e.g. `transactions.index.title`
- Always sync `en.yml` and `es.yml`

## Financial Domain

- Credit card payments (abonos) = positive income; expenses = negative
- Savings account credits = income; transfers out = expenses
- Avoid bank-specific comments — app supports multiple banks

## Workflow

1. Study existing patterns before adding new ones
2. Write specs first (TDD)
3. Run full test suite on changed files before committing
4. Ask before committing — wait for approval, propose fewer larger commits
5. Never commit debug code

## Key Directories

- `app/services/` — all service objects
- `app/views/[controller]/` — Jbuilder views
- `spec/requests/` — request specs (JSON tested here, not view specs)
- `config/locales/` — i18n files
- `app/javascript/controllers/` — Stimulus controllers
