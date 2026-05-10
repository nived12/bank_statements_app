# Rails Playwright E2E

This folder contains regression tests for the Rails web app.

## Prerequisites

- Install dependencies: `npm ci`
- Install Playwright browser once: `npx playwright install chromium`
- Use development seeds (required): `RAILS_ENV=development`

## Local Run

1. Prepare DB and seed data:
   - `RAILS_ENV=development bin/rails db:create db:schema:load db:seed`
2. Run E2E:
   - `npm run e2e`
3. Open report:
   - `npm run e2e:report`

Playwright starts Rails on `http://127.0.0.1:3001` automatically via `webServer`.

## Test Pattern

Keep tests simple: setup -> action -> assert.

- Auth setup is one line with `login(page)` in `e2e/helpers/auth.ts`.
- Reuse auth state in non-auth specs:
  - `test.use({ storageState: "e2e/.auth/user.json" })`
- Prefer stable selectors (`#email`, `#password`, form fields, links, headings).

## Adding a New Test

1. Create a new file in `e2e/tests/`, for example `goals.spec.ts`.
2. Add `storageState` line.
3. Navigate to the screen and assert one or two visible elements.

Example:

```ts
import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("goals page renders", async ({ page }) => {
  await page.goto("/goals");
  await expect(page.locator("h1").first()).toBeVisible();
});
```
