# Vittio — Claude Code Context

Personal finance app: bank statement upload, AI-powered parsing, transaction categorization, duplicate matching, financial goals. Built with Rails 8.

Full guidelines: `DEVELOPMENT.md`

## Solo-Dev Maintainability Bar

Vittio is built and maintained by a single developer. Any time you propose an implementation, design, refactor, or plan, you MUST balance two things:

1. **Solid, best-practice implementation** — proper data modeling, idiomatic Rails/React Native, real test coverage, security-aware, no shortcuts that create debt.
2. **Easy for one person to maintain forever** — minimize moving parts. Prefer fewer files, fewer tables, fewer services, fewer config layers, fewer feature flags. Every new abstraction must earn its keep.

When the two pull against each other, prefer the simpler shape — but never at the cost of correctness, security, or testability. If a proposal feels sprawling, cut it before presenting it. Ask: "If I open this code in six months, can I understand and change it in under an hour?"

Concretely:
- One service class with private methods beats six tiny services.
- Constants in the class beat a YAML config + loader.
- A nullable column beats a second table.
- Deleting old code beats feature-flagging it.
- RSpec `let` fixtures beat a fixture library.
- Inline Sentry / Rails logger beats a custom logs table.

This rule applies to every agent skill (`/be-dev`, `/fe-dev`, `/mobile-arch`, `/mobile-ux`, `/qa`) and to every planning interaction.

## Stack

- **Backend:** Ruby 3.3.0, Rails 8.x, PostgreSQL, Sidekiq, Devise, Redis
- **Frontend:** Tailwind CSS, Hotwire (Turbo Frames/Streams, Stimulus), server-side rendering
- **AI:** Google Gemini (`AI_PROVIDER=gemini`, default model `gemini-3-flash-preview`) for statement/receipt vision parsing, voice entry, and assistant LLM turns; Tesseract OCR fallback; OpenAI optional via `AI_PROVIDER=openai`
- **Mobile (planned):** Hotwire Native (iOS & Android)

## Non-Negotiable Rules

1. **Never run production commands** without explicit approval — no `RAILS_ENV=production`, no deploys
2. **Never delete records** via rails runner/console — deletions go in RSpec specs only
3. **Specs must pass — 0 failures — before any task or phase is considered complete.** Inherited failures from prior phases must be fixed, not carried forward. The only allowed failures are specs that require live external credentials, which must be wrapped in `pending` with a comment. Hard failures always block sign-off.
4. **All user-facing text** via i18n (`config/locales/en.yml` + `es.yml`) — never hardcode
5. **Always use Jbuilder** for JSON — never inline JSON in controllers
6. **Remove unused code** as you go — leave the codebase cleaner
7. **Double quotes** for all Ruby strings
8. **Any new UI behavior or behavior change must include added/updated Playwright tests**

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
- **New Stimulus controllers must be manually registered** in `app/javascript/controllers/index.js` — the manifest is not auto-discovered
- **After any JS change, run `yarn build`** — the app uses `jsbundling-rails` + esbuild, NOT importmaps. Changes to `app/javascript/` are NOT served directly; they must be bundled into `app/assets/builds/application.js`. Forgetting this is a common bug where the browser silently runs old code.
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
3. Run `rubocop -A` on changed files after every edit to auto-fix style issues
4. Run full test suite on changed files before committing
5. Ask before committing — wait for approval, propose fewer larger commits
6. Never commit debug code

## Key Directories

- `app/services/` — all service objects
- `app/views/[controller]/` — Jbuilder views
- `spec/requests/` — request specs (JSON tested here, not view specs)
- `config/locales/` — i18n files
- `app/javascript/controllers/` — Stimulus controllers
