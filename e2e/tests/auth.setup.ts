import { test as setup, expect } from "@playwright/test";
import { AUTH_FILE, login } from "../helpers/auth";

// Setup project: logs in once and saves storage state for all dependent tests.
// Runs before the chromium project (see playwright.config.ts → projects[].dependencies).
setup("authenticate", async ({ page }) => {
  await login(page);
  await expect(page.locator("h1").first()).toBeVisible();
  await page.context().storageState({ path: AUTH_FILE });
});
