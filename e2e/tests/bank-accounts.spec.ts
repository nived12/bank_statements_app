import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("bank accounts list and new form are reachable", async ({ page }) => {
  await page.goto("/bank_accounts");
  await expect(page.locator("h1").first()).toBeVisible();
  await page.locator("a[href='/bank_accounts/new']").first().click();
  await expect(page).toHaveURL(/\/bank_accounts\/new$/);
  await expect(page.locator("form[action='/bank_accounts']:visible").first()).toBeVisible();
});
