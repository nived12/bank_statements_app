import { expect, test } from "@playwright/test";
import { E2E_USER_PASSWORD } from "../helpers/credentials";
import { login } from "../helpers/auth";

// These use their own logins rather than the shared storageState: the main e2e
// user is on a trial, and making it premium would lift the free-tier gates the
// upload and assistant specs depend on. Seeded by db/seeds/playwright.rb.
const RENEWING_EMAIL = "e2e-premium@example.com";
const CANCELED_EMAIL = "e2e-canceled@example.com";

const NEXT_BILLING = /Próximo cobro|Next billing/;
const ENDS_ON = /Termina el|Ends on/;

test.describe("Subscription page billing dates", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test("a renewing subscription shows the next billing date", async ({ page }) => {
    await login(page, RENEWING_EMAIL, E2E_USER_PASSWORD);
    await page.goto("/subscription");

    const card = page.locator("body");

    // Regression guard: this line read ends_at, which Pay populates only on
    // cancellation, so it never rendered for a subscriber who was actually
    // being billed.
    await expect(card.getByText(NEXT_BILLING)).toBeVisible();
    await expect(card.getByText(ENDS_ON)).toHaveCount(0);
  });

  test("a cancelled subscription shows the end date, not a renewal", async ({ page }) => {
    await login(page, CANCELED_EMAIL, E2E_USER_PASSWORD);
    await page.goto("/subscription");

    const card = page.locator("body");

    await expect(card.getByText(ENDS_ON)).toBeVisible();
    await expect(card.getByText(NEXT_BILLING)).toHaveCount(0);
  });
});
