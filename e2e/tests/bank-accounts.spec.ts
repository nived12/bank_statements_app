import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("bank accounts list and new form are reachable", async ({ page }) => {
  await page.goto("/bank_accounts");
  await expect(page.locator("h1").first()).toBeVisible();
  await page.locator("a[href='/bank_accounts/new']").first().click();
  await expect(page).toHaveURL(/\/bank_accounts\/new$/);
  await expect(page.locator("form[action='/bank_accounts']:visible").first()).toBeVisible();
});

// `relevant_for_balance` excludes the anchor date, because the entered figure is the
// balance at the END of that day and already contains it. That is invisible arithmetic
// unless the form says so: an account anchored the day after a -1,000 transfer read
// -552.77 against a statement closing at 447.23, purely from the ambiguity.
test("the opening balance form states which side of the day the figure means", async ({ page }) => {
  await page.goto("/bank_accounts/new");

  const form = page.locator("form[action='/bank_accounts']:visible").first();
  await expect(form).toBeVisible();

  await expect(form).toContainText(/al FINAL de la fecha|at the END of the date/i);
  await expect(form).toContainText(/POSTERIORES a esta fecha|AFTER this date/i);
});
