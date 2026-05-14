# Rails Playwright E2E

Regression tests for the Rails web app (runs from repo root via `npm run e2e`).

## Prerequisites

- Rubygems: `bundle install` from the Rails app root
- Node deps: `npm ci` from the Rails app root
- Browsers once: `npx playwright install chromium`

## Local run

Playwright boots Rails on `http://127.0.0.1:3001` via `e2e/playwright.config.ts` (`webServer`).

**Default (matches local `webServer`):** Rails uses `RAILS_ENV=development` when `CI` is unset and `PLAYWRIGHT_RAILS_ENV` is not set.

1. Prepare DB and seeds:

   ```bash
   RAILS_ENV=development bin/rails db:create db:schema:load db:seed
   ```

2. Run tests:

   ```bash
   npm run e2e
   ```

3. Open HTML report:

   ```bash
   npm run e2e:report
   ```

If something is already listening on `:3001`, Playwright reuses it when not in CI — that server’s environment must match the DB you seeded.

### Match CI (`test` env)

GitHub Actions uses `RAILS_ENV=test`, `PLAYWRIGHT_RAILS_ENV=test`, `PLAYWRIGHT_E2E=1`, and a long dummy `SECRET_KEY_BASE` so seeds run in test and encrypted credentials are not required. To mirror that locally:

```bash
export SECRET_KEY_BASE="test_local_secret_do_not_use_in_production_must_be_long_enough"
export PLAYWRIGHT_E2E=1
export PLAYWRIGHT_RAILS_ENV=test
RAILS_ENV=test bin/rails db:create db:schema:load db:seed
PLAYWRIGHT_RAILS_ENV=test npm run e2e
```

## On-demand CI

- Post a PR comment containing **`run-e2e`** to run this workflow (not every push).
- For `issue_comment` triggers, GitHub uses the workflow file from the **default branch**; merge the workflow YAML there before comments will pick up changes.

## Test pattern

Keep tests simple: setup → action → assert.

- Auth: `login(page)` in `e2e/helpers/auth.ts` uses seeded credentials.
- Reuse auth in non-auth specs: `test.use({ storageState: "e2e/.auth/user.json" })`.
- Prefer stable selectors (`#email`, `#password`, forms, headings, visible text).

### Adding a test

1. Add `e2e/tests/my-feature.spec.ts`.
2. For logged-in flows, include `storageState` as in the examples below.

```ts
import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("goals page renders", async ({ page }) => {
  await page.goto("/goals");
  await expect(page.locator("h1").first()).toBeVisible();
});
```
