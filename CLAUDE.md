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
2. **Write the spec first — see Testing & TDD below. This is not optional.**
3. Run `rubocop -A` on changed files after every edit to auto-fix style issues
4. Run the specs for changed files before committing (`bin/ci-test` for the full suite)
5. Ask before committing — wait for approval, propose fewer larger commits
6. Never commit debug code

## Testing & TDD

### The loop

**Red → green → refactor, in that order.** Write a failing spec that describes
the behaviour, watch it fail *for the right reason*, then write the minimum code
to pass it.

Watching it fail is the part that gets skipped and the part that matters. A spec
that has never failed has not been shown to test anything. When you add a guard
or an edge-case assertion, prove it works by temporarily breaking the code and
confirming the spec catches it — then restore. Two examples from this codebase
that only earned trust that way: `spec/lib/schedule_yml_spec.rb` (break a queue
name) and the mailer template specs (break an i18n key).

### Coverage: ratcheting toward 90%

```bash
COVERAGE=1 bin/ci-test     # merged report at coverage/index.html
bin/coverage-check         # verify against the floor (CI runs this)
bin/coverage-check --raise # lock in an improvement, then commit the floor file
```

**Target is 90% line and branch. The floor in `.coverage-floor.json` only ever
moves up.** CI fails if either metric drops below it, so untested new code cannot
land silently. When you push coverage up, run `--raise` and commit — that is what
stops the number drifting back down.

Baseline when the ratchet was introduced: **75.79% line, 54.17% branch**. Branch
coverage is the weaker number and the more useful one to raise; it counts whether
both sides of each conditional were exercised, which is where the bugs in this
codebase have actually lived.

Getting there is incremental: cover what you touch. Every new service, job, or
endpoint should land at or above 90%, and any file you modify is a chance to
close its gaps.

**Aim high on domain logic — services, jobs, models, mailers, controllers — but
do not confuse the number with correctness.** Line coverage measures which lines
executed, not whether behaviour is right; optimising purely for it produces tests
that assert trivia while real gaps survive.

The cautionary tale is in this repo: `Recurring::DailyDueJob` and its
`DueProcessor` were well covered and every spec passed, yet the job **never ran a
single time in production** for two months. Nothing scheduled it, and no unit
test can see that. Coverage was not the missing thing; a test of the wiring was.

So:
- **Every bug fix starts with a spec that reproduces the bug.** No exceptions —
  that spec is the proof the fix works and the guard against regression.
- **Test behaviour and edges**, not lines: nil, zero, empty, boundary dates,
  timezone rollover, concurrent writes, "job ran twice", "job never ran".
- **Test the wiring, not just the units.** If something must be registered,
  scheduled, or enqueued to work at all, assert that too.
- Prefer request specs over controller specs; JSON is asserted in request specs.
- Do not write tests purely to raise the number — schema annotations, plain
  delegations, and generated scaffolding are exempt.

### What must have a spec

| Change | Required |
|---|---|
| Service object, job, mailer | Unit spec incl. failure paths |
| New/changed endpoint | Request spec (status, JSON shape, authz) |
| Bug fix | A spec that fails before the fix |
| Gating / permission logic | Both allowed and denied paths |
| Config that can silently no-op (cron, queues, initializers) | A spec asserting it is wired |
| User-visible UI/flow change | Playwright e2e — **propose before writing** (see root `CLAUDE.md`) |

### Running specs

```bash
bundle exec rspec spec/path/to/file_spec.rb   # while working — fastest loop
bin/ci-test                                    # full suite, parallel (~2.5min vs ~7.5min)
bin/ci-test -n 2                               # fewer processes
COVERAGE=1 bin/ci-test                         # + merged coverage report
```

`bin/ci-test` is for **local** runs, where spare cores make in-process
parallelism a big win. Each process gets its own database
(`bank_statements_app_test`, `_test2`, …) via `TEST_ENV_NUMBER` in
`config/database.yml`.

**CI shards across runners instead**, because a GitHub runner has only 4 vCPU:
4 rspec processes plus the Postgres container saturate it, and measurements
showed each example running ~3x slower — a 13m46s serial suite came down only to
12m. Four separate runners each get four real CPUs. The workflow runs
`parallel_rspec -n 4 --only-group ${{ matrix.shard }}`, which uses
`TEST_ENV_NUMBER=""`, so every shard just uses the plain test database on its own
Postgres container.

The `coverage` job runs on its own runner alongside the shards, so its ~12m
never gates the ~5m test feedback. It is **advisory on PRs, enforcing on main**:
a drop shows the number on the PR (red check, merge not blocked) and fails for
real once merged. Treat a red coverage check on a PR as a to-do, not a
formality — that is the whole point of it being visible while the code is fresh.

**Never set `DATABASE_URL` for the test environment.** It overrides
`database.yml` wholesale, including the per-process suffix, which silently puts
every process on one database — where `DatabaseCleaner`'s `before(:suite)`
truncation in one process wipes tables another is mid-example on. This is why
`.env.test` sets `PGHOST` instead.

### Keeping specs parallel-safe

Specs must not depend on each other or on shared mutable state:

- **No shared external state.** Do not write to Redis, fixed file paths, or
  global config. Temp dirs need a unique suffix — the blog specs use
  `Rails.root.join("tmp", "test_blog_content_#{SecureRandom.hex(4)}")`.
- **No load-order assumptions.** When stubbing `ENV`, always set
  `and_call_original` *before* narrowing with `.with(...)`, for **both** `[]` and
  `fetch`. Missing this on `fetch` made `statement_ingest_job_*_spec` pass only
  when another file happened to autoload `Ai::VisionClient` first — invisible in
  a full serial run, fatal once files are split across processes.
- **Use `travel_to`**, never real sleeps or wall-clock assumptions.
- If a spec passes alone but fails in the suite (or vice versa), that is a real
  bug in the spec — fix it, do not reorder around it.

## Key Directories

- `app/services/` — all service objects
- `app/views/[controller]/` — Jbuilder views
- `spec/requests/` — request specs (JSON tested here, not view specs)
- `config/locales/` — i18n files
- `app/javascript/controllers/` — Stimulus controllers
