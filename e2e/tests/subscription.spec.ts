import { expect, test } from "@playwright/test";
import { E2E_USER_PASSWORD } from "../helpers/credentials";
import { login } from "../helpers/auth";

// These use their own logins rather than the shared storageState: the main e2e
// user is on a trial, and making it premium would lift the free-tier gates the
// upload and assistant specs depend on. Seeded by db/seeds/playwright.rb.
const RENEWING_EMAIL = "e2e-premium@example.com";
const CANCELED_EMAIL = "e2e-canceled@example.com";
const LEGACY_ANNUAL_EMAIL = "e2e-legacy-annual@example.com";

const NEXT_BILLING = /Próximo cobro|Next billing/;
const ENDS_ON = /Termina el|Ends on/;
const PLAN_ANNUAL = /Plan Anual|Annual Plan/;
const PLAN_MONTHLY = /Plan Mensual|Monthly Plan/;
const ANY_PRICE_LINE = /MX\$[\d,]+\.\d\d\s*\/\s*(mes|año|mo|yr)/;

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

test.describe("Subscription page plan and amount", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  // Regression guard for two bugs that shipped together. The interval came from
  // comparing processor_plan against the currently configured annual price id, and
  // the amount was a hardcoded i18n string of today's list price. Stripe Prices are
  // immutable, so a price change strands every existing subscriber on a retired id —
  // and the card then reported the wrong plan *and* the wrong number, to the people
  // who had been paying longest.
  test("an annual subscriber on a retired price sees their real plan and amount", async ({ page }) => {
    await login(page, LEGACY_ANNUAL_EMAIL, E2E_USER_PASSWORD);
    await page.goto("/subscription");

    const card = page.locator("body");

    await expect(card.getByText(PLAN_ANNUAL)).toBeVisible();
    await expect(card.getByText(PLAN_MONTHLY)).toHaveCount(0);

    // What they actually pay, not the configured $899.
    await expect(card.getByText("MX$1,188.00", { exact: false })).toBeVisible();
    await expect(card.getByText("MX$899.00", { exact: false })).toHaveCount(0);
  });

  // Comped accounts have no Stripe price behind them, so there is no interval and no
  // amount to report. Falling back to a list price would invent a bill the account
  // does not have.
  test("a manually granted subscription shows no plan label and no amount", async ({ page }) => {
    await login(page, RENEWING_EMAIL, E2E_USER_PASSWORD);
    await page.goto("/subscription");

    const card = page.locator("body");

    await expect(card.getByText(/Activo|Active/).first()).toBeVisible();
    await expect(card.getByText(PLAN_ANNUAL)).toHaveCount(0);
    await expect(card.getByText(PLAN_MONTHLY)).toHaveCount(0);
    await expect(card.getByText(ANY_PRICE_LINE)).toHaveCount(0);
  });
});
