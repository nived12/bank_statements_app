# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: e2e/tests/recurring.spec.ts >> authenticated user >> renders the recurring index page or redirects when subscription gate denies
- Location: e2e/tests/recurring.spec.ts:11:7

# Error details

```
Error: page.goto: Protocol error (Page.navigate): Cannot navigate to invalid URL
Call log:
  - navigating to "/recurring", waiting until "load"

```

# Test source

```ts
  1  | import { expect, test } from "@playwright/test";
  2  | 
  3  | test("unauthenticated visit redirects to sign in", async ({ page }) => {
  4  |   await page.goto("/recurring");
  5  |   await expect(page).toHaveURL(/\/session\/new/);
  6  | });
  7  | 
  8  | test.describe("authenticated user", () => {
  9  |   test.use({ storageState: "e2e/.auth/user.json" });
  10 | 
  11 |   test("renders the recurring index page or redirects when subscription gate denies", async ({ page }) => {
> 12 |     await page.goto("/recurring");
     |                ^ Error: page.goto: Protocol error (Page.navigate): Cannot navigate to invalid URL
  13 |     // Either user has access (sees the recurring page) or is redirected to /pricing
  14 |     const url = page.url();
  15 |     if (/\/pricing/.test(url)) {
  16 |       test.skip(true, "subscription gate denied user — pricing page reached");
  17 |       return;
  18 |     }
  19 |     await expect(page.getByRole("heading", { name: /Recurr(ing|entes)/i })).toBeVisible();
  20 |     await expect(page.getByText(/Monthly total|Total mensual/i)).toBeVisible();
  21 |     await expect(page.getByText(/Annual total|Total anual/i)).toBeVisible();
  22 |   });
  23 | 
  24 |   test("'New recurring' link routes to the form", async ({ page }) => {
  25 |     await page.goto("/recurring");
  26 |     if (/\/pricing/.test(page.url())) {
  27 |       test.skip(true, "subscription gate denied");
  28 |       return;
  29 |     }
  30 |     await page.getByRole("link", { name: /New recurring|Nuevo recurrente/i }).click();
  31 |     await expect(page).toHaveURL(/\/recurring\/new/);
  32 |     await expect(page.getByLabel(/Name|Nombre/i)).toBeVisible();
  33 |     await expect(page.getByLabel(/Expected amount|Monto/i, { exact: false })).toBeVisible();
  34 |   });
  35 | 
  36 |   test("Transactions page shows 'Recurrentes' tab and navigates correctly", async ({ page }) => {
  37 |     await page.goto("/transactions");
  38 |     if (/\/pricing/.test(page.url())) {
  39 |       test.skip(true, "subscription gate denied");
  40 |       return;
  41 |     }
  42 |     const recurringTab = page.getByRole("link", { name: /Recurrentes|Recurring/i }).first();
  43 |     await expect(recurringTab).toBeVisible();
  44 |     await recurringTab.click();
  45 |     await expect(page).toHaveURL(/\/recurring($|\?)/);
  46 |     // Active state of the parent sidebar should still cover the recurring controller
  47 |     await expect(page.getByText(/Monthly total|Total mensual/i)).toBeVisible();
  48 |   });
  49 | });
  50 | 
```