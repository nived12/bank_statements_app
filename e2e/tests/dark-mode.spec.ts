import { expect, test, type Page } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

// Force dark mode before any page script runs. The layout's inline boot script
// reads localStorage["vittio-theme"] and stamps data-theme on <html>, so seeding
// it here makes every navigation render in dark mode.
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.localStorage.setItem("vittio-theme", "dark");
  });
});

// Smoke coverage for the dark-mode contrast fixes: we can't meaningfully assert
// pixel-level contrast, so instead we guard against regressions where a page
// fails to render or throws while in dark mode.
async function expectRendersInDarkMode(page: Page, path: string) {
  const pageErrors: Error[] = [];
  page.on("pageerror", (error) => pageErrors.push(error));

  await page.goto(path);

  // Boot script applied the dark theme.
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

  // The page actually rendered content, not a blank/error shell.
  await expect(page.locator("main, form").first()).toBeVisible();

  // No uncaught JS exceptions while rendering in dark mode.
  expect(pageErrors, `Uncaught errors on ${path}: ${pageErrors.map((e) => e.message).join("; ")}`).toEqual([]);
}

test("dashboard renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/");
});

test("bank account form renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/bank_accounts/new");
});

test("savings form (contribution mode) renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/savings/new");
});

test("debt form (payment mode) renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/debts/new");
});
