import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";
import { desktopView } from "../helpers/desktop";
import { mxTodayIsoDate } from "../helpers/transactions";

test.use({ storageState: AUTH_FILE });

// A saving/debt stores the balance the user typed plus the date it was true. Only
// transactions after that date move it. Before this existed, the typed figure was
// discarded the moment anything linked — "I already have $50,000" became $500.
// mxTodayIsoDate rather than a UTC date: the page renders Date.current in the request's
// timezone, and TimezoneConcern falls back to America/Mexico_City when nothing supplies
// one — a Playwright browser sends no timezone header. Computing it in UTC failed nightly
// between 00:00 and 06:00 UTC, when the two are a day apart.
const today = mxTodayIsoDate;

test.describe("Balance anchor — savings", () => {
  test("the balance date defaults to today and cannot be set in the future", async ({ page }) => {
    await page.goto("/savings/new");

    const date = desktopView(page).locator("#saving_opening_balance_date");
    await expect(date).toHaveValue(today());
    // A future anchor would count transactions that haven't happened yet.
    await expect(date).toHaveAttribute("max", today());
  });

  test("the typed baseline survives creation instead of being recomputed to zero", async ({ page }) => {
    await page.goto("/savings/new");

    const form = desktopView(page);
    await form.locator("#saving_name").fill("E2E Anchor Fund");
    await form.locator("#saving_target_amount").fill("120000");
    await form.locator("#saving_opening_balance").fill("50000");
    await form.getByRole("button", { name: /Crear Ahorro/i }).click();

    await page.waitForURL(/\/savings\/\d+/, { timeout: 15_000 });
    await expect(desktopView(page).getByText(/50,000/).first()).toBeVisible();
  });

  test("re-opening the form shows the same date back, with no drift", async ({ page }) => {
    await page.goto("/savings/new");
    const form = desktopView(page);
    await form.locator("#saving_name").fill("E2E Anchor Roundtrip");
    await form.locator("#saving_target_amount").fill("1000");
    await form.locator("#saving_opening_balance").fill("100");
    await form.locator("#saving_opening_balance_date").fill("2026-01-15");
    await form.getByRole("button", { name: /Crear Ahorro/i }).click();
    await page.waitForURL(/\/savings\/\d+/, { timeout: 15_000 });

    const id = page.url().match(/\/savings\/(\d+)/)![1];
    await page.goto(`/savings/${id}/edit`);

    await expect(desktopView(page).locator("#saving_opening_balance_date")).toHaveValue("2026-01-15");
  });
});

test.describe("Balance anchor — debts", () => {
  test("the balance date defaults to today and cannot be set in the future", async ({ page }) => {
    await page.goto("/debts/new");

    const date = desktopView(page).locator("#debt_opening_balance_date");
    await expect(date).toHaveValue(today());
    await expect(date).toHaveAttribute("max", today());
  });

  test("the typed balance survives creation instead of reverting to the principal", async ({ page }) => {
    await page.goto("/debts/new");

    const form = desktopView(page);
    await form.locator("#debt_name").fill("E2E Anchor Card");
    await form.locator("#debt_original_amount").fill("100000");
    await form.locator("#debt_opening_balance").fill("60000");
    await form.getByRole("button", { name: /Crear Deuda/i }).click();

    await page.waitForURL(/\/debts\/\d+/, { timeout: 15_000 });
    // debts/show has no `hidden md:block` shell — it is one responsive page — so this
    // asserts on the page rather than through desktopView().
    // The old formula recomputed this from original_amount and would show 100,000.
    await expect(page.getByText(/60,000/).first()).toBeVisible();
    await expect(page.getByText(/100,000\.00/).first()).toBeVisible(); // original_amount, unchanged
  });
});
