import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("dashboard renders key sections", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("h1").first()).toBeVisible();
  await expect(page.locator("a[href='/bank_accounts']").first()).toBeVisible();
  await expect(page.locator("a[href='/transactions']").first()).toBeVisible();
});
