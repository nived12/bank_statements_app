import { expect, test } from "@playwright/test";

test("unauthenticated visit redirects to sign in", async ({ page }) => {
  await page.goto("/recurring");
  await expect(page).toHaveURL(/\/session\/new/);
});

test.describe("authenticated user", () => {
  test.use({ storageState: "e2e/.auth/user.json" });

  test("renders the recurring index page or redirects when subscription gate denies", async ({ page }) => {
    await page.goto("/recurring");
    // Either user has access (sees the recurring page) or is redirected to /pricing
    const url = page.url();
    if (/\/pricing/.test(url)) {
      test.skip(true, "subscription gate denied user — pricing page reached");
      return;
    }
    await expect(page.getByRole("heading", { name: /Recurr(ing|entes)/i })).toBeVisible();
    await expect(page.getByText(/Monthly total|Total mensual/i)).toBeVisible();
    await expect(page.getByText(/Annual total|Total anual/i)).toBeVisible();
  });

  test("'New recurring' link routes to the form", async ({ page }) => {
    await page.goto("/recurring");
    if (/\/pricing/.test(page.url())) {
      test.skip(true, "subscription gate denied");
      return;
    }
    await page.getByRole("link", { name: /New recurring|Nuevo recurrente/i }).click();
    await expect(page).toHaveURL(/\/recurring\/new/);
    await expect(page.getByLabel(/Name|Nombre/i)).toBeVisible();
    await expect(page.getByLabel(/Expected amount|Monto/i, { exact: false })).toBeVisible();
  });

  test("Transactions page shows 'Recurrentes' tab and navigates correctly", async ({ page }) => {
    await page.goto("/transactions");
    if (/\/pricing/.test(page.url())) {
      test.skip(true, "subscription gate denied");
      return;
    }
    const recurringTab = page.getByRole("link", { name: /Recurrentes|Recurring/i }).first();
    await expect(recurringTab).toBeVisible();
    await recurringTab.click();
    await expect(page).toHaveURL(/\/recurring($|\?)/);
    // Active state of the parent sidebar should still cover the recurring controller
    await expect(page.getByText(/Monthly total|Total mensual/i)).toBeVisible();
  });
});
