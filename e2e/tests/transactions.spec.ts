import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("transactions page renders", async ({ page }) => {
  await page.goto("/transactions");
  await expect(page.locator("h1").first()).toBeVisible();
  await expect(page.locator("input[name='search'][type='text']").first()).toBeVisible();
});
