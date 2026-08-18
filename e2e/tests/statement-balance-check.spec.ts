import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";

test.use({ storageState: AUTH_FILE });

// Statements::BalanceVerifier detects and records a discrepancy, but for a while nothing
// read it back: `statement_type_data["balance_check"]` was written on every import and
// shown nowhere, so a statement whose rows did not reconcile looked exactly like one that
// did. The check protected nobody it was built for.
//
// The seeded statement (db/seeds/playwright.rb) declares 1,000 -> 3,000 and carries a
// single 1,200 row, so 800 pesos of movement are missing. Its balance_check is produced by
// running the real verifier in the seed, not hand-written, so this fails if the identity
// itself regresses.
test("a statement whose rows miss the closing balance says so, with the amount", async ({ page }) => {
  await page.goto("/statement_files");

  const link = page.locator("a[aria-label*='e2e-unbalanced-statement']").first();
  await expect(link).toBeAttached();
  await link.click();

  await expect(page).toHaveURL(/\/statement_files\/\d+$/);

  const warning = page
    .locator(".statement-file-warning")
    .filter({ hasText: /no cuadran|don't add up/i })
    .first();

  await expect(warning).toBeVisible();
  // The amount is the whole point: it tells the user which row to go looking for.
  await expect(warning).toContainText("$800.00");
});

// The counterpart, and the one that matters more in production: almost every statement
// reconciles, and a warning on those would train people to ignore the one that counts.
// The seeded balanced statement declares the same 1,000 -> 3,000 and carries a 2,000 row,
// so it lands exactly on the closing balance and `balance_discrepancy` returns nil.
test("a statement that reconciles shows no warning", async ({ page }) => {
  await page.goto("/statement_files");

  const link = page.locator("a[aria-label*='e2e-balanced-statement']").first();
  await expect(link).toBeAttached();
  await link.click();

  await expect(page).toHaveURL(/\/statement_files\/\d+$/);
  // The page itself must have rendered, or "no warning" would pass on a blank screen.
  await expect(page.locator(".statement-file-overview")).toBeVisible();

  await expect(
    page.locator(".statement-file-warning").filter({ hasText: /no cuadran|don't add up/i })
  ).toHaveCount(0);
});
